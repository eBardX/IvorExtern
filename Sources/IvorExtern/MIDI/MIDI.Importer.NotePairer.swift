// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMIDI

extension MIDI.Importer {

    // Pairs a single channel's note-on/note-off messages into sounding
    // notes (FIFO per key) while collecting that channel's `.panMSB`
    // control changes, tick-ordered. The upstream `ignoreErrors`/
    // `stripMetaText` options are dropped along with the type that carried
    // them, since the importer never set either one.
    internal struct NotePairer {

        // MARK: Internal Initializers

        internal init(channel: MIDI.Channel) {
            self.channel = channel
            self.notes = []
            self.openNotes = [:]
            self.panEvents = []
            self.programChangeEvents = []
        }

        // MARK: Private Instance Properties

        private let channel: MIDI.Channel

        private var notes: [MIDI.Note]
        private var openNotes: [MIDI.NoteNumber: [(startTime: MIDI.EventTime, onVelocity: MIDI.KeyVelocity)]]
        private var panEvents: [SMFEvent]
        private var programChangeEvents: [SMFEvent]
    }
}

// MARK: -

extension MIDI.Importer.NotePairer {

    // MARK: Internal Instance Methods

    // Ignores every channel event other than note-on, note-off, `.panMSB`
    // control change, and program change. Throws `.unexpectedNoteOff` for a
    // note-off (or a zero-velocity note-on) with no open note-on.
    internal mutating func ingest(_ event: SMFEvent) throws(MIDI.Error) {
        guard case let .midi(time, message) = event
        else { return }

        switch message {
        case let .noteOn(_, key, velocity) where velocity.uintValue == 0:
            try _closeNote(key: key,
                           offTime: time,
                           offVelocity: velocity)

        case let .noteOn(_, key, velocity):
            openNotes[key, default: []].append((time, velocity))

        case let .noteOff(_, key, velocity):
            try _closeNote(key: key,
                           offTime: time,
                           offVelocity: velocity)

        case .controlChange(_, .panMSB, _):
            panEvents.append(event)

        case .programChange:
            programChangeEvents.append(event)

        default:
            break
        }
    }

    // Throws `.unpairedNoteOn` if any note-on has no matching note-off.
    internal mutating func makeVoice(name: String) throws(MIDI.Error) -> MIDI.Voice {
        try _checkPendingNotes()

        return MIDI.Voice(channel: channel,
                          name: name,
                          notes: notes.sorted { $0.startTime < $1.startTime },
                          panEvents: panEvents,
                          programChangeEvents: programChangeEvents)
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
                               startTime: open.startTime))
    }
}
