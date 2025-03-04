import HelperCoders
import MetaCodable
import Testing

@testable import PluginCore

struct CodedAsTests {
    @Test
    func misuseOnGroupedVariableDeclaration() throws {
        assertMacroExpansion(
            """
            struct SomeCodable {
                @CodedAs("alt")
                let one, two, three: String
            }
            """,
            expandedSource:
                """
                struct SomeCodable {
                    let one, two, three: String
                }
                """,
            diagnostics: [
                .multiBinding(line: 2, column: 5)
            ]
        )
    }

    @Test
    func misuseOnStaticVariableDeclaration() throws {
        assertMacroExpansion(
            """
            struct SomeCodable {
                @CodedAs("alt")
                static let value: String
            }
            """,
            expandedSource:
                """
                struct SomeCodable {
                    static let value: String
                }
                """,
            diagnostics: [
                .init(
                    id: CodedAs.misuseID,
                    message:
                        "@CodedAs can't be used with static variables declarations",
                    line: 2, column: 5,
                    fixIts: [
                        .init(message: "Remove @CodedAs attribute")
                    ]
                )
            ]
        )
    }

    @Test
    func misuseInCombinationWithIgnoreCodingMacro() throws {
        assertMacroExpansion(
            """
            struct SomeCodable {
                @CodedAs("alt")
                @IgnoreCoding
                let one: String = "some"
            }
            """,
            expandedSource:
                """
                struct SomeCodable {
                    let one: String = "some"
                }
                """,
            diagnostics: [
                .init(
                    id: CodedAs.misuseID,
                    message:
                        "@CodedAs can't be used in combination with @IgnoreCoding",
                    line: 2, column: 5,
                    fixIts: [
                        .init(message: "Remove @CodedAs attribute")
                    ]
                ),
                .init(
                    id: IgnoreCoding.misuseID,
                    message:
                        "@IgnoreCoding can't be used in combination with @CodedAs",
                    line: 3, column: 5,
                    fixIts: [
                        .init(message: "Remove @IgnoreCoding attribute")
                    ]
                ),
            ]
        )
    }

    @Test
    func duplicatedMisuse() throws {
        assertMacroExpansion(
            """
            struct SomeCodable {
                @CodedAs("two")
                @CodedAs("three")
                let one: String
            }
            """,
            expandedSource:
                """
                struct SomeCodable {
                    let one: String
                }
                """,
            diagnostics: [
                .init(
                    id: CodedAs.misuseID,
                    message:
                        "@CodedAs can only be applied once per declaration",
                    line: 2, column: 5,
                    fixIts: [
                        .init(message: "Remove @CodedAs attribute")
                    ]
                ),
                .init(
                    id: CodedAs.misuseID,
                    message:
                        "@CodedAs can only be applied once per declaration",
                    line: 3, column: 5,
                    fixIts: [
                        .init(message: "Remove @CodedAs attribute")
                    ]
                ),
            ]
        )
    }

    struct WithValue {
        @Codable
        struct SomeCodable {
            @CodedAs("key")
            let value: String
            @CodedAs("key1", "key2")
            let value1: String
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct SomeCodable {
                    @CodedAs("key")
                    let value: String
                    @CodedAs("key1", "key2")
                    let value1: String
                }
                """,
                expandedSource:
                    """
                    struct SomeCodable {
                        let value: String
                        let value1: String
                    }

                    extension SomeCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            let valueKeys = [CodingKeys.value, CodingKeys.key].filter {
                                container.allKeys.contains($0)
                            }
                            guard valueKeys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.value = try container.decode(String.self, forKey: valueKeys[0])
                            let value1Keys = [CodingKeys.value1, CodingKeys.key1, CodingKeys.key2].filter {
                                container.allKeys.contains($0)
                            }
                            guard value1Keys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.value1 = try container.decode(String.self, forKey: value1Keys[0])
                        }
                    }

                    extension SomeCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try container.encode(self.value, forKey: CodingKeys.value)
                            try container.encode(self.value1, forKey: CodingKeys.value1)
                        }
                    }

                    extension SomeCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case key = "key"
                            case value = "value"
                            case key1 = "key1"
                            case key2 = "key2"
                            case value1 = "value1"
                        }
                    }
                    """
            )
        }
    }

    struct WithHelperAndValue {
        @Codable
        struct SomeCodable {
            @CodedAs("key")
            @CodedBy(
                SequenceCoder(output: [String].self, configuration: .lossy)
            )
            let value: [String]
            @CodedAs("key1", "key2")
            @CodedBy(
                SequenceCoder(output: [String].self, configuration: .lossy)
            )
            let value1: [String]
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct SomeCodable {
                    @CodedAs("key")
                    @CodedBy(SequenceCoder(output: [String].self, configuration: .lossy))
                    let value: [String]
                    @CodedAs("key1", "key2")
                    @CodedBy(SequenceCoder(output: [String].self, configuration: .lossy))
                    let value1: [String]
                }
                """,
                expandedSource:
                    """
                    struct SomeCodable {
                        let value: [String]
                        let value1: [String]
                    }

                    extension SomeCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            let valueKeys = [CodingKeys.value, CodingKeys.key].filter {
                                container.allKeys.contains($0)
                            }
                            guard valueKeys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.value = try SequenceCoder(output: [String].self, configuration: .lossy).decode(from: container, forKey: valueKeys[0])
                            let value1Keys = [CodingKeys.value1, CodingKeys.key1, CodingKeys.key2].filter {
                                container.allKeys.contains($0)
                            }
                            guard value1Keys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.value1 = try SequenceCoder(output: [String].self, configuration: .lossy).decode(from: container, forKey: value1Keys[0])
                        }
                    }

                    extension SomeCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try SequenceCoder(output: [String].self, configuration: .lossy).encode(self.value, to: &container, atKey: CodingKeys.value)
                            try SequenceCoder(output: [String].self, configuration: .lossy).encode(self.value1, to: &container, atKey: CodingKeys.value1)
                        }
                    }

                    extension SomeCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case key = "key"
                            case value = "value"
                            case key1 = "key1"
                            case key2 = "key2"
                            case value1 = "value1"
                        }
                    }
                    """
            )
        }
    }

    struct WithDefaultValue {
        @Codable
        struct SomeCodable {
            @CodedAs("key")
            @Default("some")
            let value: String
            @CodedAs("key1", "key2")
            @Default("some")
            let value1: String
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct SomeCodable {
                    @CodedAs("key")
                    @Default("some")
                    let value: String
                    @CodedAs("key1", "key2")
                    @Default("some")
                    let value1: String
                }
                """,
                expandedSource:
                    """
                    struct SomeCodable {
                        let value: String
                        let value1: String
                    }

                    extension SomeCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try? decoder.container(keyedBy: CodingKeys.self)
                            if let container = container {
                                do {
                                    let valueKeys = [CodingKeys.value, CodingKeys.key].filter {
                                        container.allKeys.contains($0)
                                    }
                                    guard valueKeys.count == 1 else {
                                        let context = DecodingError.Context(
                                            codingPath: container.codingPath,
                                            debugDescription: "Invalid number of keys found, expected one."
                                        )
                                        throw DecodingError.typeMismatch(Self.self, context)
                                    }
                                    self.value = try container.decodeIfPresent(String.self, forKey: valueKeys[0]) ?? "some"
                                } catch {
                                    self.value = "some"
                                }
                                do {
                                    let value1Keys = [CodingKeys.value1, CodingKeys.key1, CodingKeys.key2].filter {
                                        container.allKeys.contains($0)
                                    }
                                    guard value1Keys.count == 1 else {
                                        let context = DecodingError.Context(
                                            codingPath: container.codingPath,
                                            debugDescription: "Invalid number of keys found, expected one."
                                        )
                                        throw DecodingError.typeMismatch(Self.self, context)
                                    }
                                    self.value1 = try container.decodeIfPresent(String.self, forKey: value1Keys[0]) ?? "some"
                                } catch {
                                    self.value1 = "some"
                                }
                            } else {
                                self.value = "some"
                                self.value1 = "some"
                            }
                        }
                    }

                    extension SomeCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try container.encode(self.value, forKey: CodingKeys.value)
                            try container.encode(self.value1, forKey: CodingKeys.value1)
                        }
                    }

                    extension SomeCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case key = "key"
                            case value = "value"
                            case key1 = "key1"
                            case key2 = "key2"
                            case value1 = "value1"
                        }
                    }
                    """
            )
        }
    }

    struct WithHelperAndDefaultValue {
        @Codable
        struct SomeCodable {
            @CodedAs("key")
            @CodedBy(
                SequenceCoder(output: [String].self, configuration: .lossy)
            )
            @Default(["some"])
            let value: [String]
            @CodedAs("key1", "key2")
            @CodedBy(
                SequenceCoder(output: [String].self, configuration: .lossy)
            )
            @Default(["some"])
            let value1: [String]
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct SomeCodable {
                    @CodedAs("key")
                    @CodedBy(SequenceCoder(output: [String].self, configuration: .lossy))
                    @Default(["some"])
                    let value: [String]
                    @CodedAs("key1", "key2")
                    @CodedBy(SequenceCoder(output: [String].self, configuration: .lossy))
                    @Default(["some"])
                    let value1: [String]
                }
                """,
                expandedSource:
                    """
                    struct SomeCodable {
                        let value: [String]
                        let value1: [String]
                    }

                    extension SomeCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try? decoder.container(keyedBy: CodingKeys.self)
                            if let container = container {
                                do {
                                    let valueKeys = [CodingKeys.value, CodingKeys.key].filter {
                                        container.allKeys.contains($0)
                                    }
                                    guard valueKeys.count == 1 else {
                                        let context = DecodingError.Context(
                                            codingPath: container.codingPath,
                                            debugDescription: "Invalid number of keys found, expected one."
                                        )
                                        throw DecodingError.typeMismatch(Self.self, context)
                                    }
                                    self.value = try SequenceCoder(output: [String].self, configuration: .lossy).decodeIfPresent(from: container, forKey: valueKeys[0]) ?? ["some"]
                                } catch {
                                    self.value = ["some"]
                                }
                                do {
                                    let value1Keys = [CodingKeys.value1, CodingKeys.key1, CodingKeys.key2].filter {
                                        container.allKeys.contains($0)
                                    }
                                    guard value1Keys.count == 1 else {
                                        let context = DecodingError.Context(
                                            codingPath: container.codingPath,
                                            debugDescription: "Invalid number of keys found, expected one."
                                        )
                                        throw DecodingError.typeMismatch(Self.self, context)
                                    }
                                    self.value1 = try SequenceCoder(output: [String].self, configuration: .lossy).decodeIfPresent(from: container, forKey: value1Keys[0]) ?? ["some"]
                                } catch {
                                    self.value1 = ["some"]
                                }
                            } else {
                                self.value = ["some"]
                                self.value1 = ["some"]
                            }
                        }
                    }

                    extension SomeCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try SequenceCoder(output: [String].self, configuration: .lossy).encode(self.value, to: &container, atKey: CodingKeys.value)
                            try SequenceCoder(output: [String].self, configuration: .lossy).encode(self.value1, to: &container, atKey: CodingKeys.value1)
                        }
                    }

                    extension SomeCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case key = "key"
                            case value = "value"
                            case key1 = "key1"
                            case key2 = "key2"
                            case value1 = "value1"
                        }
                    }
                    """
            )
        }
    }

    struct CodingKeyCaseNameCollisionHandling {
        @Codable
        struct TestCodable {
            @CodedAs("fooBar", "foo_bar")
            var fooBar: String
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct TestCodable {
                    @CodedAs("fooBar", "foo_bar")
                    var fooBar: String
                }
                """,
                expandedSource:
                    """
                    struct TestCodable {
                        var fooBar: String
                    }

                    extension TestCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            let fooBarKeys = [CodingKeys.fooBar, CodingKeys.__macro_local_6fooBarfMu0_].filter {
                                container.allKeys.contains($0)
                            }
                            guard fooBarKeys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.fooBar = try container.decode(String.self, forKey: fooBarKeys[0])
                        }
                    }

                    extension TestCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try container.encode(self.fooBar, forKey: CodingKeys.fooBar)
                        }
                    }

                    extension TestCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case fooBar = "fooBar"
                            case __macro_local_6fooBarfMu0_ = "foo_bar"
                        }
                    }
                    """
            )
        }
    }

    struct CodingKeyCaseNameCollisionHandlingWithDuplicateAliases {
        @Codable
        struct TestCodable {
            @CodedAs("fooBar", "foo_bar", "foo_bar")
            var fooBar: String
        }

        @Test
        func expansion() throws {
            assertMacroExpansion(
                """
                @Codable
                struct TestCodable {
                    @CodedAs("fooBar", "foo_bar", "foo_bar")
                    var fooBar: String
                }
                """,
                expandedSource:
                    """
                    struct TestCodable {
                        var fooBar: String
                    }

                    extension TestCodable: Decodable {
                        init(from decoder: any Decoder) throws {
                            let container = try decoder.container(keyedBy: CodingKeys.self)
                            let fooBarKeys = [CodingKeys.fooBar, CodingKeys.__macro_local_6fooBarfMu0_].filter {
                                container.allKeys.contains($0)
                            }
                            guard fooBarKeys.count == 1 else {
                                let context = DecodingError.Context(
                                    codingPath: container.codingPath,
                                    debugDescription: "Invalid number of keys found, expected one."
                                )
                                throw DecodingError.typeMismatch(Self.self, context)
                            }
                            self.fooBar = try container.decode(String.self, forKey: fooBarKeys[0])
                        }
                    }

                    extension TestCodable: Encodable {
                        func encode(to encoder: any Encoder) throws {
                            var container = encoder.container(keyedBy: CodingKeys.self)
                            try container.encode(self.fooBar, forKey: CodingKeys.fooBar)
                        }
                    }

                    extension TestCodable {
                        enum CodingKeys: String, CodingKey, CaseIterable {
                            case fooBar = "fooBar"
                            case __macro_local_6fooBarfMu0_ = "foo_bar"
                        }
                    }
                    """
            )
        }
    }
}
