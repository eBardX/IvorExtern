// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI
internal import IvorSMF

extension MIDI.Importer {

    // Pairs a single channel's note-on/note-off messages into sounding
    // notes (FIFO per key) while collecting that channel's `.panMSB` and
    // Bank Select (`.bankSelectMSB`/`.bankSelectLSB`) control changes,
    // tick-ordered. The upstream `ignoreErrors`/`stripMetaText` options are
    // dropped along with the type that carried them, since the importer
    // never set either one.
    internal struct NotePairer {

        // MARK: Internal Initializers

        internal init(channel: MIDI.Channel) {
            self.bankSelectEvents = []
            self.channel = channel
            self.expressionEvents = []
            self.notes = []
            self.openNotes = [:]
            self.panEvents = []
            self.programChangeEvents = []
            self.volumeEvents = []
        }

        // MARK: Private Instance Properties

        private let channel: MIDI.Channel

        private var bankSelectEvents: [SMFEvent]
        private var expressionEvents: [SMFEvent]
        private var notes: [MIDI.Note]
        private var openNotes: [MIDI.NoteNumber: [(startTime: MIDI.EventTime,
                                                   onVelocity: MIDI.KeyVelocity,
                                                   peakKeyPressure: MIDIData1Value?)]]
        private var panEvents: [SMFEvent]
        private var programChangeEvents: [SMFEvent]
        private var volumeEvents: [SMFEvent]
    }
}

// MARK: -

extension MIDI.Importer.NotePairer {

    // MARK: Internal Instance Methods

    // Ignores every channel event other than note-on, note-off, `.panMSB`
    // control change, Bank Select control change, and program change.
    // Throws `.unexpectedNoteOff` for a note-off (or a zero-velocity
    // note-on) with no open note-on.
    internal mutating func ingest(_ event: SMFEvent) throws(MIDI.Error) {
        guard case let .midi(time, message) = event
        else { return }

        switch message {
        case let .noteOn(_, key, velocity) where velocity.uintValue == 0:
            try _closeNote(key: key,
                           offTime: time,
                           offVelocity: velocity)

        case let .noteOn(_, key, velocity):
            openNotes[key, default: []].append((time, velocity, nil))

        case let .noteOff(_, key, velocity):
            try _closeNote(key: key,
                           offTime: time,
                           offVelocity: velocity)

        case let .polyphonicPressure(_, key, pressure):
            if var opens = openNotes[key], !opens.isEmpty {
                let lastIndex = opens.count - 1
                let peak = max(opens[lastIndex].peakKeyPressure?.uintValue ?? 0, pressure.uintValue)

                opens[lastIndex].peakKeyPressure = MIDIData1Value(uintValue: peak)
                openNotes[key] = opens
            }

        case .controlChange(_, .panLSB, _),
             .controlChange(_, .panMSB, _):
            panEvents.append(event)

        case .controlChange(_, .bankSelectLSB, _),
             .controlChange(_, .bankSelectMSB, _):
            bankSelectEvents.append(event)

        case .controlChange(_, .expressionControllerLSB, _),
             .controlChange(_, .expressionControllerMSB, _):
            expressionEvents.append(event)

        case .controlChange(_, .channelVolumeMSB, _):
            volumeEvents.append(event)

        case .programChange:
            programChangeEvents.append(event)

        default:
            break
        }
    }

    // Throws `.unpairedNoteOn` if any note-on has no matching note-off.
    internal mutating func makeVoice(name: String) throws(MIDI.Error) -> MIDI.Voice {
        try _checkPendingNotes()

        return MIDI.Voice(bankSelectEvents: bankSelectEvents,
                          channel: channel,
                          expressionEvents: expressionEvents,
                          name: name,
                          notes: notes.sorted { $0.startTime < $1.startTime },
                          panEvents: panEvents,
                          programChangeEvents: programChangeEvents,
                          volumeEvents: volumeEvents)
    }

    // MARK: Private Instance Methods

    private mutating func _checkPendingNotes() throws(MIDI.Error) {
        let pending = openNotes.flatMap { key, opens in
            opens.map { (key: key, startTime: $0.startTime) }
        }.sorted {
            $0.startTime != $1.startTime ? $0.startTime < $1.startTime : $0.key.uintValue < $1.key.uintValue
        }

        guard let first = pending.first
        else { return }

        throw MIDI.Error.unpairedNoteOn(channel: channel,
                                        key: first.key,
                                        time: first.startTime)
    }

    private mutating func _closeNote(key: MIDI.NoteNumber,
                                     offTime: MIDI.EventTime,
                                     offVelocity: MIDI.KeyVelocity) throws(MIDI.Error) {
        guard var opens = openNotes[key],
              !opens.isEmpty
        else { throw MIDI.Error.unexpectedNoteOff(channel: channel, key: key, time: offTime) }

        let open = opens.removeFirst()

        openNotes[key] = opens

        notes.append(MIDI.Note(duration: offTime.uintValue - open.startTime.uintValue,
                               key: key,
                               offVelocity: offVelocity,
                               onVelocity: open.onVelocity,
                               peakKeyPressure: open.peakKeyPressure,
                               startTime: open.startTime))
    }
}
