import Darwin

struct InterpretationError: Error {
    var message: String
}

public class TinyForth {
    typealias Value = Int
    typealias Block = () throws -> Void

    class Dictionary {
        struct Entry {
            var name: String
            var immediate: Bool
            var block: Block
        }

        var entries: [String: Entry] = [:]

        func word(_ name: String, block: @escaping Block) {
            entries[name] = Entry(name: name, immediate: false, block: block)
        }

        func immediateWord(_ name: String, block: @escaping Block) {
            entries[name] = Entry(name: name, immediate: true, block: block)
        }

        func aliasWord(_ newName: String, oldName: String) {
            let oldEntry = entries[oldName]!
            let newEntry = Entry(name: newName, immediate: oldEntry.immediate, block: oldEntry.block)
            entries[newName] = newEntry
        }

        subscript(_ name: String) -> Entry? {
            get { entries[name] }
            set { entries[name] = newValue }
        }
    }

    var dictionary: Dictionary = Dictionary()
    var stack: [Value] = []

    public init() {
        initializeDictionary()
    }

    func initializeDictionary() {
        dictionary.word("dup", block: dup)
        dictionary.word("q_dup", block: q_dup)
        dictionary.word("drop", block: drop)
        dictionary.word("swap", block: swap)
        dictionary.word("over", block: over)
        dictionary.word("rot", block: rot)
        dictionary.word("plus", block: plus)
        dictionary.word("mult", block: mult)
        dictionary.word("subtract", block: subtract)
        dictionary.word("divide", block: divide)
        dictionary.word("dot", block: dot)
        dictionary.word("cr", block: cr)
        dictionary.word("dot_s", block: dot_s)
        dictionary.word("dot_d", block: dot_d)

        dictionary.aliasWord("?dup", oldName: "q_dup")
        dictionary.aliasWord("+", oldName: "plus")
        dictionary.aliasWord("*", oldName: "mult")
        dictionary.aliasWord("-", oldName: "subtract")
        dictionary.aliasWord("/", oldName: "divide")
        dictionary.aliasWord(".", oldName: "dot")
        dictionary.aliasWord(".S", oldName: "dot_s")
        dictionary.aliasWord(".D", oldName: "dot_d")

        dictionary.word(":") { try self.readAndDefineWord() }
        dictionary.word("bye") { exit(0) }

        dictionary.immediateWord("\\") { _ = readLine() }
    }

    func defineWord(_ name: String, words: [String]) throws {
        dictionary.word(name, block: try self.compileWords(words))
    }

    func compileWords(_ words: [String]) throws -> Block {
        var blocks: [Block] = []
        for word in words {
            let entry = resolveWord(word)!
            if entry.immediate {
                try entry.block()
            } else {
                blocks.append(entry.block)
            }
        }
        return {
            for block in blocks {
                try block()
            }
        }
    }

    func readAndDefineWord() throws {
        guard let name = readWord() else { fatalError() }
        var words: [String] = []
        while let word = readWord() {
            if word == ";" { break }
            words.append(word)
        }
        _ = try dictionary.word(name, block: compileWords(words))
    }

    func resolveWord(_ word: String) -> Dictionary.Entry? {
        if let entry = dictionary[word] { return entry }
        if let number = Int(word) {
            let block = { self.stack.append(number) }
            return Dictionary.Entry(name: word, immediate: false, block: block)
        }
        return nil
    }

    func forthEval(_ word: String) throws {
        guard let entry = resolveWord(word) else { throw InterpretationError(message: "Unknown word '\(word)'") }
        try entry.block()
    }

    var inputBuffer: [String] = []

    func readWord() -> String? {
        guard !inputBuffer.isEmpty else { return nil }
        return inputBuffer.removeFirst()
    }

    public func eval(_ input: String) throws {
        inputBuffer.append(contentsOf: input.split(separator: " ").map(String.init))
        while !inputBuffer.isEmpty {
            try forthEval(readWord()!)
        }
    }

    // -- primitive words --

    func dup() {
        stack.append(stack.last!)
    }

    func q_dup() {
        if stack.last != 0 { dup() }
    }

    func drop() {
        _ = stack.popLast()
    }

    func swap() {
        let (a, b) = (stack.popLast()!, stack.popLast()!)
        stack.append(contentsOf: [a, b])
    }

    func over() {
        let (a, b) = (stack.popLast()!, stack.popLast()!)
        stack.append(contentsOf: [b, a, b])
    }

    func rot() {
        let (a, b, c) = (stack.popLast()!, stack.popLast()!, stack.popLast()!)
        stack.append(contentsOf: [b, a, c])
    }

    private func arithmeticOp(_ op: (Int, Int) -> (Int)) {
        let (a, b) = (stack.popLast()!, stack.popLast()!)
        stack.append(op(b, a))
    }

    func plus()     { arithmeticOp(+) }
    func mult()     { arithmeticOp(*) }
    func subtract() { arithmeticOp(-) }
    func divide()   { arithmeticOp(/) }

    func dot() throws {
        guard let value = stack.popLast() else { throw InterpretationError(message: "Stack is empty") }
        print(value)
    }

    func cr() {
        print()
    }

    func dot_s() {
        print("\(stack)")
    }

    func dot_d() {
        dump(dictionary)
    }
}
