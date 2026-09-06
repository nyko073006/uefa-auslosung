/// Landesverband (Association) eines Teams, z.B. "ENG", "GER" oder "ESP".
///
/// Fachregeln: Teams derselben Association duerfen nicht gegeneinander spielen,
/// und kein Team darf mehr als zwei Gegner aus derselben Association bekommen.
public struct Association: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    /// Kurzcode des Verbands, z.B. "ENG".
    public let rawValue: String

    /// Erzeugt eine Association aus ihrem Kurzcode.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Bequemer Kurz-Initialisierer, z.B. `Association("ENG")`.
    public init(_ value: String) {
        self.rawValue = value
    }

    /// Totalordnung ueber den rawValue. Damit bleiben Sortierungen ueber
    /// Associations deterministisch und unabhaengig von Hash-Seeds.
    public static func < (lhs: Association, rhs: Association) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Dekodiert die Association als einfachen String (kein verschachteltes Objekt).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    /// Kodiert die Association als einfachen String.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Stabile, eindeutige Kennung eines Teams.
///
/// Wird ueberall dort verwendet, wo Paarungen und Ereignisse auf Teams verweisen,
/// damit keine vollstaendigen `Team`-Werte kopiert werden muessen.
public struct TeamID: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    /// Kennung des Teams, z.B. "FCB".
    public let rawValue: String

    /// Erzeugt eine TeamID aus ihrem Rohwert.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Bequemer Kurz-Initialisierer, z.B. `TeamID("FCB")`.
    public init(_ value: String) {
        self.rawValue = value
    }

    /// Totalordnung ueber den rawValue. Grundlage fuer alle kanonischen
    /// Sortierungen im Package.
    public static func < (lhs: TeamID, rhs: TeamID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Dekodiert die TeamID als einfachen String (kein verschachteltes Objekt).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    /// Kodiert die TeamID als einfachen String.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Einer der vier Loskoerbe (Toepfe) mit je neun Teams.
///
/// Jedes Team bekommt genau zwei Gegner aus jedem Topf, auch aus dem eigenen.
public enum Pot: Int, CaseIterable, Hashable, Comparable, Sendable, Codable {
    /// Topf 1 (staerkste Teams).
    case pot1 = 1
    /// Topf 2.
    case pot2
    /// Topf 3.
    case pot3
    /// Topf 4.
    case pot4

    /// Totalordnung ueber den rawValue: pot1 < pot2 < pot3 < pot4.
    public static func < (lhs: Pot, rhs: Pot) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Ein teilnehmendes Team der Auslosung.
///
/// Value-Type ohne Referenzen: Identitaet ergibt sich allein aus `id`,
/// Gleichheit vergleicht dagegen alle Felder.
public struct Team: Hashable, Identifiable, Sendable, Codable {
    /// Eindeutige Kennung des Teams.
    public let id: TeamID
    /// Anzeigename des Teams.
    public let name: String
    /// Landesverband des Teams.
    public let association: Association
    /// Topf, aus dem das Team gezogen wird.
    public let pot: Pot

    /// Erzeugt ein Team aus seinen vier Stammdaten.
    public init(id: TeamID, name: String, association: Association, pot: Pot) {
        self.id = id
        self.name = name
        self.association = association
        self.pot = pot
    }
}
