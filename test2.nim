import stardust
import std/[macros, dom]


proc parseFormatString(s: string, openChar = '{', closeChar = '}'): NimNode =
  if s.len == 0:
    result = newStrLitNode("")
  elif s.len > 0:
    var stringNode: seq[NimNode]
    var i = 0
    var part = ""
    block outer:
      while i < s.len:
        if s[i] == openChar:
          if part.len > 0:
            stringNode.add newStrLitNode(part)
            part.setLen(0)
          inc i
          while i < s.len:
            if s[i] == closeChar:
              stringNode.add newCall(ident"toString", parseExpr(part))
              part.setLen(0)
              inc i
              break
            else:
              part.add s[i]
              inc i
        else:
          part.add s[i]
          inc i
    if part.len > 0:
      stringNode.add newStrLitNode(part)
    result = stringNode[^1]
    for i in countdown(stringNode.len-2, 0):
      result = newCall(ident"concat", stringNode[i], result)

macro fmt*(x: static string): cstring =
  parseFormatString(x)


proc toUpperCase(x: cstring): cstring {.importjs: "#.toUpperCase()".}

when true:
  proc createDom(): Element =
    var name = cstring"world"
    buildHtml:
      h1:
        text fmt"Hello {name.toUpperCase()}!"

  setRender createDom

when false:
  var counter1 = 0
  var counter2 = 0.5
  # proc click() =
  #   inc counter2
  proc createDom(): Element =
    buildHtml:
      h1:
        text "Conquer World!"
      `div`:
        text "{counter1} => {counter2} => {counter1}"
        button:
          text fmt"{counter1}"
      h2:
        `div`:
          text "hello"
        text fmt"{counter1} => {counter2} => {counter1}"
        # button(onclick = click)
        # text b"{counter}"


  proc main() =
    setRender createDom

  main()

when false:
  proc getCstring(): cstring =
    result = "we are cool".cstring

  proc createDom(): Element =
    result = buildHtml:
      h1:
        text getCstring()
  proc main() =
    setRender createDom
  main()

when false:
  var counter1 = 0
  var counter2 = 0.5
  # proc click() =
  #   inc counter2

  proc createDom(): Element =
    buildHtml:
      h1:
        text "Conquer World"
      `div`:
        text fmt"{counter1}"
        button:
          text "{counter2}"
      h2:
        text "{counter1}"
        `div`:
          text "hello"
        # button(onclick = click)
        # text b"{counter}"

  proc main() =
    setRender createDom

  main()