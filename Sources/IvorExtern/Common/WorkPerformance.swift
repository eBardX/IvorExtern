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
/// For now every note sounds at a fixed velocity, and a note that glides
/// plays its start key only. Only a keyboard-pitch, wall-time work can be
/// made into a performance.
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
        var partChannelSets: [[MIDIChannel]] = []

        for (part, channel) in zip(parts, partChannels) {
            let (partEvents, channels) = Self._events(for: part,
                                                      on: channel,
                                                      realization: realization)

            events += partEvents

            partChannelSets.append(channels)
        }

        self.duration = events.map(\.time).max() ?? .zero
        self.events = events.sorted()
        self.partChannels = partChannels
        self.partChannelSets = partChannelSets
    }

    // MARK: Public Instance Properties

    /// When the last note ends, or zero for a work with no notes.
    public let duration: WallTime

    /// The events, in the order they are sent.
    public let events: [Event]

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
    private static let velocity = MIDIData1Value(clamping: 100)

    // MARK: Private Type Methods

    // A part's events, and every channel it plays on. Its instruments are taken in the order they come in: each
    // channel's first patch is sent at the start, and a later one only if it differs from the channel's patch by then.
    private static func _events(for part: Part<WallTime, NoteNumber>,
                                on partChannel: MIDIChannel,
                                realization: Realization?) -> ([Event], [MIDIChannel]) {
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

        for note in part.noteTable {
            let (channel, _) = resolve(part.instrumentMap[note.attack])
            let key = MIDIData1Value(clamping: note.startPitch.uintValue)

            events.append(Event(time: note.attack,
                                message: .noteOn(channel, key, velocity)))
            events.append(Event(time: note.release,
                                message: .noteOff(channel, key, MIDIData1Value(clamping: 0))))
        }

        return (events, patches.keys.sorted())
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
            MIDIChannel(clamping: 10)
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
