// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorMIDI
public import IvorModel
public import IvorTiming

private import IvorTuning

/// A work as a MIDI player plays it: every part’s channel messages, each at
/// its time in the work, in the order they are sent.
///
/// The times are kept exactly as the work has them — never as
/// floating-point seconds — so that events at the same time are ordered as
/// ``Event`` says, never by rounding. Each part has a channel of its own,
/// skipping channel 10, which General MIDI keeps for percussion, until there
/// are more parts than channels, when they share.
///
/// Each of a part’s instruments sounds as the realization assigns it — the
/// part’s own assignment, else the realization’s default — and plays on the
/// assignment’s channel, if it names one, or a percussion patch on channel
/// 10, or else on the part’s own channel. An instrument the realization
/// doesn’t assign sounds as ``IvorMIDI/MIDIPatch/init(instrument:)`` has it.
/// Every channel a part uses gets its first patch at the start, so an
/// instrument change that moves to another channel sends no program change
/// partway through; one that stays on the channel sends one, after a bank
/// select if the patch has a bank, or if the channel’s previous patch had
/// one, which is then reset to bank 0 (see
/// ``IvorMIDI/MIDIPatch/selectionMessages(on:after:)``).
///
/// Each note sounds at the velocity of the part’s dynamic level at its
/// attack, so a crescendo rises note by note — or, where an importer kept
/// the note’s exact velocity (its `attackVelocity` extra), at that.
///
/// Pan and expression are per channel, so each channel takes those of the
/// first part that plays on it, and a later part that shares the channel
/// sends none. A part sends its pan on every channel it owns at the start,
/// and again at a pan-map entry or one of its attacks where the pan has
/// changed, and throughout a glide while a note sounds. An entry’s exact
/// 14-bit pan, where an importer kept one, is sent as it is.
///
/// A part also sends expression (CC 11) on every channel it owns except
/// percussion, starting at the start, so that a crescendo or diminuendo
/// reaches a note already sounding, wherever a held note would otherwise
/// drift audibly from the written level. The expression is relative to the
/// velocity: a note attacking during one has a higher velocity, so it still
/// sounds at the written level. Where an importer kept a file’s exact
/// expression (the `expressionValue` extra of a dynamic-map entry), that is
/// sent as it is instead.
///
/// Every note says which part it belongs to, so that a mixer can mute one
/// part of several sharing a channel. The performance itself sends no channel
/// volume (CC 7), which it leaves to the mixer.
///
/// For now a note that glides plays its start key only. Only a
/// keyboard-pitch, wall-time work can be made into a performance.
public struct WorkPerformance {

    // MARK: Public Initializers

    /// Creates a `WorkPerformance` instance for the provided work, as the
    /// provided realization assigns its sounds, or `nil` if the work isn’t
    /// in keyboard pitch and wall time.
    ///
    /// - Parameter work:           The work to perform.
    /// - Parameter realization:    The realization that assigns the work’s
    ///                             sounds, or `nil` for every instrument to
    ///                             sound as its name picks.
    public init?(work: Work,
                 realization: Realization? = nil) {
        guard case let .keyboardWall(parts) = work.content
        else { return nil }

        let partChannels = parts.indices.map { Self.channels[$0 % Self.channels.count] }
        var events: [Event] = []
        var ownedChannels: Set<MIDIChannel> = []
        var ownedChannelSets: [[MIDIChannel]] = []
        var partChannelSets: [[MIDIChannel]] = []
        var partSounds: [[Instrument: (MIDIChannel, MIDIPatch)]] = []

        for (part, channel) in zip(parts, partChannels) {
            let (patchEvents, channels, sounds) = Self._patchEvents(for: part,
                                                                    on: channel,
                                                                    realization: realization)

            events += patchEvents

            partChannelSets.append(channels)
            partSounds.append(sounds)
        }

        for (index, part) in parts.enumerated() {
            let channels = partChannelSets[index].filter { ownedChannels.insert($0).inserted }
            let expressive = channels.filter { $0 != Self.percussionChannel }
            let expression = Expression(part: part)

            ownedChannelSets.append(channels)

            events += Self._noteEvents(for: part,
                                       at: index,
                                       sounds: partSounds[index],
                                       expression: expression,
                                       on: Set(expressive))
            events += Self._panEvents(for: part,
                                      on: channels,
                                      expression: expression)
            events += expression.events(on: expressive)
        }

        self.duration = events.map(\.time).max() ?? .zero
        self.events = events.sorted()
        self.ownedChannelSets = ownedChannelSets
        self.partChannels = partChannels
        self.partChannelSets = partChannelSets
    }

    // MARK: Public Instance Properties

    /// When the last note ends, or zero for a work with no notes.
    public let duration: WallTime

    /// The events, in the order they are sent.
    public let events: [Event]

    /// The channels each part owns, in the work’s order: those of its
    /// ``partChannelSets`` that no earlier part plays on.
    ///
    /// Only a channel’s owner sends it pan and expression, and a mixer that
    /// sets a part’s volume should likewise set only these, so a part that
    /// owns none has no volume of its own.
    public let ownedChannelSets: [[MIDIChannel]]

    /// The channel each part plays on unless an assignment says otherwise,
    /// in the work’s order.
    public let partChannels: [MIDIChannel]

    /// Every channel each part plays on, in the work’s order: its own, and
    /// any its instruments’ assignments move it to.
    public let partChannelSets: [[MIDIChannel]]
}

// MARK: -

extension WorkPerformance {

    // MARK: Public Instance Methods

    /// Returns which output each channel plays through, given each part’s.
    ///
    /// A channel goes where the first part that plays on it goes, and a
    /// channel no part plays on goes nowhere.
    ///
    /// - Parameter partOutputs:    Each part’s output, in the work’s order.
    ///
    /// - Returns:  Sixteen outputs, one for each channel from channel 1, as
    ///             a MIDI router takes them.
    public func channelOutputs<Output>(forPartOutputs partOutputs: [Output]) -> [Output?] {
        var outputs = [Output?](repeating: nil,
                                count: 16)

        for (channels, output) in zip(partChannelSets, partOutputs).reversed() {
            for channel in channels {
                outputs[Int(channel.uintValue) - 1] = output
            }
        }

        return outputs
    }

    // MARK: Private Type Properties

    private static let channels = (1...16).filter { $0 != 10 }.map { MIDIChannel(clamping: $0) }
    private static let defaultVelocity = MIDIData1Value(clamping: 64)
    private static let percussionChannel = MIDIChannel(clamping: 10)

    // MARK: Private Type Methods

    // A part's notes. An attack on one of `expressiveChannels` takes account of the expression there.
    private static func _noteEvents(for part: Part<WallTime, NoteNumber>,
                                    at partIndex: Int,
                                    sounds: [Instrument: (MIDIChannel, MIDIPatch)],
                                    expression: Expression,
                                    on expressiveChannels: Set<MIDIChannel>) -> [Event] {
        var events: [Event] = []

        for note in part.noteTable {
            guard let (channel, _) = sounds[part.instrumentMap[note.attack]]
            else { continue }

            let key = MIDIData1Value(clamping: note.startPitch.uintValue)
            let velocity = exactKeyVelocity(note.extras)
                ?? convertToMIDIKeyVelocity(part.dynamicMap[note.attack])
                ?? defaultVelocity
            let attackVelocity = expressiveChannels.contains(channel) ? expression.velocity(velocity, at: note.attack) : velocity

            events.append(Event(time: note.attack,
                                message: .noteOn(channel, key, attackVelocity),
                                partIndex: partIndex))
            events.append(Event(time: note.release,
                                message: .noteOff(channel, key, MIDIData1Value(clamping: 0)),
                                partIndex: partIndex))
        }

        return events
    }

    // A part's patch changes, every channel it plays on, and how each of its instruments sounds. Its instruments are
    // taken in the order they come in: each channel's first patch is sent at the start, and a later one only if it
    // differs from the channel's patch by then.
    private static func _patchEvents(for part: Part<WallTime, NoteNumber>,
                                     on partChannel: MIDIChannel,
                                     realization: Realization?) -> ([Event], [MIDIChannel], [Instrument: (MIDIChannel, MIDIPatch)]) {
        var resolved: [Instrument: (MIDIChannel, MIDIPatch)] = [:]

        func resolve(_ instrument: Instrument) -> (MIDIChannel, MIDIPatch) {
            if let known = resolved[instrument] {
                return known
            }

            let result = _resolve(instrument,
                                  in: part.partID,
                                  on: partChannel,
                                  realization: realization)

            resolved[instrument] = result

            return result
        }

        var changes = [(time: WallTime.zero, instrument: part.instrumentMap[.zero])]

        for entry in part.instrumentMap where entry.time > .zero {
            changes.append((entry.time, entry.instrument))
        }

        var events: [Event] = []
        var patches: [MIDIChannel: MIDIPatch] = [:]

        for (time, instrument) in changes {
            let (channel, patch) = resolve(instrument)
            let previous = patches[channel]

            guard previous != patch
            else { continue }

            let eventTime = previous == nil ? WallTime.zero : time

            for message in patch.selectionMessages(on: channel,
                                                   after: previous) {
                events.append(Event(time: eventTime,
                                    message: message))
            }

            patches[channel] = patch
        }

        return (events, patches.keys.sorted(), resolved)
    }

    // A part's pan on `channels`, the ones it owns.
    private static func _panEvents(for part: Part<WallTime, NoteNumber>,
                                   on channels: [MIDIChannel],
                                   expression: Expression) -> [Event] {
        guard !channels.isEmpty
        else { return [] }

        let (times, exactPans) = _panTimes(for: part,
                                           expression: expression)

        var events: [Event] = []
        var previous: (msb: MIDIData1Value, lsb: MIDIData1Value?)?

        for time in times {
            let value: (msb: MIDIData1Value, lsb: MIDIData1Value?)

            if let midiPan = exactPans[time] {
                let raw = UInt(clamping: midiPan)

                value = (MIDIData1Value(clamping: raw >> 7), MIDIData1Value(clamping: raw & 0x7f))
            } else if let msb = convertToMIDIPanValue(part.panMap[time]) {
                value = (msb, nil)
            } else {
                continue
            }

            guard previous.map({ $0.msb != value.msb || $0.lsb != value.lsb }) ?? true
            else { continue }

            previous = value

            for channel in channels {
                events.append(Event(time: time,
                                    message: .controlChange(channel, .panMSB, value.msb)))

                if let lsb = value.lsb {
                    events.append(Event(time: time,
                                        message: .controlChange(channel, .panLSB, lsb)))
                }
            }
        }

        return events
    }

    // The times a part's pan may change, in order, and the exact pans among them.
    private static func _panTimes(for part: Part<WallTime, NoteNumber>,
                                  expression: Expression) -> ([WallTime], [WallTime: Int]) {
        var exactPans: [WallTime: Int] = [:]
        var times: Set<WallTime> = [.zero]

        for entry in part.panMap {
            times.insert(entry.time)

            if let midiPan = intValue(entry.extras, .midiPan) {
                exactPans[entry.time] = midiPan
            }
        }

        for note in part.noteTable {
            times.insert(note.attack)
        }

        for (start, end) in zip(part.panMap, part.panMap.dropFirst()) where start.time < end.time && start.pan != end.pan {
            times.formUnion(expression.gridTimes(from: start.time,
                                                 through: end.time))
        }

        return (times.sorted(), exactPans)
    }

    private static func _resolve(_ instrument: Instrument,
                                 in partID: PartID,
                                 on partChannel: MIDIChannel,
                                 realization: Realization?) -> (MIDIChannel, MIDIPatch) {
        guard let assignment = realization?.assignment(for: instrument,
                                                       in: partID)
        else { return (partChannel, MIDIPatch(instrument: instrument)) }

        let channel = if let channel = assignment.channel {
            MIDIChannel(clamping: channel)
        } else if assignment.patch.isPercussion {
            percussionChannel
        } else {
            partChannel
        }

        return (channel, MIDIPatch(patch: assignment.patch))
    }
}

// MARK: - Equatable

extension WorkPerformance: Equatable {
}

// MARK: - Sendable

extension WorkPerformance: Sendable {
}
