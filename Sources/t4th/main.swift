import TinyForth

var forth = TinyForth()

while true {
    print("> ", terminator: "")
    do {
        try forth.eval(readLine()!)
    } catch {
        print(error)
    }
}
