import std/macros
import aqua/web/doms
import std/strutils

proc getName(n: NimNode): string =
  case n.kind
  of nnkIdent, nnkSym:
    result = $n
  of nnkAccQuoted:
    result = ""
    for i in 0..<n.len:
      result.add getName(n[i])
  of nnkStrLit..nnkTripleStrLit:
    result = n.strVal
  of nnkInfix:
    # allow 'foo-bar' syntax:
    if n.len == 3 and $n[0] == "-":
      result = getName(n[1]) & "-" & getName(n[2])
    else:
      expectKind(n, nnkIdent)
  of nnkDotExpr:
    result = getName(n[0]) & "." & getName(n[1])
  of nnkOpenSymChoice, nnkClosedSymChoice:
    result = getName(n[0])
  else:
    expectKind(n, nnkIdent)

import std/[sets, strformat]

var buildTable {.compileTime.} = toHashSet([
    "a", "abbr", "acronym", "address", "applet", "area", "article",
    "aside", "audio",
    "b", "base", "basefont", "bdi", "bdo", "big", "blockquote", "body",
    "br", "button", "canvas", "caption", "center", "cite", "code",
    "col", "colgroup", "command",
    "datalist", "dd", "del", "details", "dfn", "dialog", "div",
    "dir", "dl", "dt", "em", "embed", "fieldset",
    "figcaption", "figure", "font", "footer",
    "form", "frame", "frameset", "h1", "h2", "h3",
    "h4", "h5", "h6", "head", "header", "hgroup", "html", "hr",
    "i", "iframe", "img", "input", "ins", "isindex",
    "kbd", "keygen", "label", "legend", "li", "link", "map", "mark",
    "menu", "meta", "meter", "nav", "nobr", "noframes", "noscript",
    "object", "ol",
    "optgroup", "option", "output", "p", "param", "pre", "progress", "q",
    "rp", "rt", "ruby", "s", "samp", "script", "section", "select", "small",
    "source", "span", "strike", "strong", "style",
    "sub", "summary", "sup", "table",
    "tbody", "td", "textarea", "tfoot", "th", "thead", "time",
    "title", "tr", "track", "tt", "u", "ul", "var", "video", "wbr"])

var illegalTag {.compileTime.} = toHashSet(["body", "head", "html", "title", "script"])

import std/sugar


proc toString*[T](x: T): cstring {.importjs: "#.toString()".}

proc concat*(x1, x2: cstring): cstring {.importjs: "(# + #)".}

type
  Watcher = ref object
    fn: proc (): cstring
    callback: proc (value: cstring) {.closure.}
    value: cstring
  Monitor = ref object
    watchers: seq[Watcher]


proc detect(monitor: Monitor) =
  while true:
    var changes = 0
    for w in monitor.watchers:
      let value = w.fn()
      if value != w.value:
        w.callback(value)
        w.value = value
        inc changes
    if changes == 0:
      break

proc construct(monitor: NimNode, parentElement: NimNode, res: var string,
                    count: var int,
                    textCount: var int,
                    node: NimNode,
                    isCall: static bool = false,
                    countNode = newEmptyNode()): NimNode


import std/tables
var buildTableNode {.compileTime.}: Table[string, NimNode]
var constructedTableNode {.compileTime.}: Table[string, NimNode]
var countNodeTable {.compileTime.}: Table[string, NimNode]
var countTableNode {.compileTime.}: Table[string, int]

type
  ComponentContext* = object
    monitor: NimNode
    parent: NimNode
    res: string
    count, textCount: int


macro component*(x: untyped) =
  # expectKind(x, nnkProcDef)
  # let defs = newIdentDefs(ident"componentContext",
  #                         newTree(nnkStaticTy, ident"ComponentContext")
  #                        )
  # x[3].insert(1, defs)
  echo "here: ", x[0].getName
  # result = x

  echo x.repr

  buildTableNode[x[0].getName] = x
  countTableNode[x[0].getName] = 0


proc apply(monitor: Monitor) =
  discard setTimeout(() => detect(monitor), 10)

proc bindText*(monitor: Monitor, element: Element, fn: proc (): cstring) =
  let watcher = Watcher(fn: fn, callback: (value: cstring) => (element.textContent = value), value: "")
  monitor.watchers.add watcher

proc setAttr[T: cstring|bool](x: Element; name: cstring, value: T) {.importjs: "#[#] = #".}
proc getAttr(x: Element; name: cstring): cstring {.importjs: "#[#]".}

proc getChecked(x: Element; name: cstring): bool {.importjs: "#[#]".}


proc bindInput*(monitor: Monitor, element: Element, name: cstring, variable: var bool,
                getCallBack: proc (): cstring, setCallBack: proc(x: Watcher, node: Element, y: var bool)) =
  let watcher = Watcher(fn: getCallBack, callback: 
    (value: cstring) => (element.setAttr(name, if value == "true": true else: false)), value: "")
  monitor.watchers.add watcher
  addEventListener(element, "input", (ev: Event) => setCallBack(watcher, element, variable))

proc bindInput*(monitor: Monitor, element: Element, name: cstring, variable: var cstring,
                getCallBack: proc (): cstring, setCallBack: proc(x: Watcher, node: Element, y: var cstring)) =
  let watcher = Watcher(fn: getCallBack, callback: (value: cstring) => (element.setAttr(name, value)), value: "")
  monitor.watchers.add watcher
  addEventListener(element, "input", (ev: Event) => setCallBack(watcher, element, variable))

proc construct(monitor: NimNode, parentElement: NimNode, res: var string,
                    count: var int,
                    textCount: var int,
                    node: NimNode,
                    isCall: static bool = false,
                    countNode = newEmptyNode()): NimNode =
  case node.kind
  of nnkStmtList, nnkStmtListExpr:

    textCount = 0 # todo

    result = newNimNode(node.kind, node)
    for x in node:
      let tmp = construct(monitor, parentElement, res, count, textCount, x)
      if tmp.kind != nnkEmpty:
        result.add tmp

    textCount = 0 # todo
  of nnkCallKinds - {nnkInfix}:
    let name = getName(node[0])
    if name in buildTable:
      if name in illegalTag:
        error(fmt"{name} is not allowed", node)
      textCount = 0 # todo
      # check the length of node
      var parentNode =
        when isCall:
          var access = newNimNode(nnkBracketExpr)
          access.add parentElement
          access.add countNode
          access
        else:
          if count == 0:
            quote do:
              cast[Element](`parentElement`.firstChild)
          else:
            quote do:
              `parentElement`[`count`]
      inc count
      let isSingleTag = name in ["input", "br"]
      if node.len == 1:
        result = newEmptyNode()
        if isSingleTag:
          res.add fmt"<{name}/>"
        else:
          res.add fmt"<{name}></{name}>"
      else:
        var part = ""
        var partCount = 0
        if isSingleTag:
          res.add fmt"<{name}"
        result = newStmtList()
        for i in 1..<node.len:
          let x = node[i]
          if x.kind == nnkExprEqExpr:
            let name = getName(x[0])
            if name.startsWith("on"):
              let variable = x[1]
              if name == "onChecked":
                result.add quote do:
                  bindInput(`monitor`, `parentNode`, cstring"checked",
                            `variable`, () => `variable`.toString(),
                            proc (x: Watcher, node: Element, y: var bool) =
                              y = getChecked(node, "checked");
                              x.value = y.toString()
                              apply(`monitor`)
                            )
              elif name == "onClick":
                result.add quote do:
                  addEventListener(`parentNode`, "click", (ev: Event) => (`variable`(ev); apply(`monitor`)))
              else:
                let newName = name[2..^1].toLowerAscii
                result.add quote do:
                  bindInput(`monitor`, `parentNode`, `newName`.cstring,
                            `variable`, () => `variable`,
                            proc (x: Watcher, node: Element, y: var cstring) =
                              x.value = getAttr(node, `newName`.cstring);
                              y = x.value;
                              apply(`monitor`)
                            )
            else:
              # todo x1.kind
              res.add fmt" {name}={x[1].strVal}"
              # result.add newCall(bindSym"setAttr", parentNode, newStrLitNode(name), x[1])
          else:
            if isSingleTag:
              error(fmt"A empty element({name}) is not allowed to have children", x)
            result.add construct(monitor, parentNode, part, partCount, textCount, x)
            res.add fmt"<{name}>{part}</{name}>"
        if isSingleTag:
          res.add ">"
      textCount = 0 # todo
    elif name == "text":
      if textCount == 1:
         error("The text node is not allowed to use sequentially", node)
      inc textCount # todo
      case node[1].kind:
      of nnkStrLit:
        res.add node[1].strVal
        result = newEmptyNode()
      else:
        res.add " "
        var currentNode =
          if count == 0:
            quote do:
              cast[Element](`parentElement`.firstChild) #! Node
          else:
            quote do:
              `parentElement`[`count`]

        # ! bug cannot inline node[1]
        let tmp = node[1]
        result = quote do:
          bindText(`monitor`, `currentNode`, () => `tmp`)
      inc count
    else:
      # 
      echo "there: ", node[0].getName
      # echo buildTableNode[node[0].getName].treeRepr
      let temp = quote do:
        `node`
      echo "================================="
      echo temp.treeRepr
      echo symbol(temp[0]).getImpl.treeRepr
      echo "================================="

      # echo node.repr
      const bodyPos = 6
      if countTableNode[node[0].getName] == 0:
        const paramsPos = 3
        let def = buildTableNode[node[0].getName]
        let passedCount = genSym(nskParam, "count")
        let params = def[paramsPos]
        let staticCount = newNimNode(nnkStaticTy)
        staticCount.add ident"int"
        params.insert(1, newIdentDefs(passedCount, ident"int"))
      # let staticMonitor = newNimNode(nnkStaticTy)
      # staticMonitor.add bindSym"Monitor"
      # params.insert(2, newIdentDefs(ident(monitor.strVal), bindSym"Monitor"))
      # let staticElement = newNimNode(nnkStaticTy)
      # staticElement.add bindSym"Element"
      # params.insert(3, newIdentDefs(ident(parentElement.strVal), bindSym"Node"))
        echo def.treerepr

        let body = def[bodyPos][0]
        body.del(0)
        constructedTableNode[node[0].getName] = buildTableNode[node[0].getName].copy
        buildTableNode[node[0].getName][bodyPos][0] = construct(monitor, parentElement, res,
                      count, textCount, body, isCall = true, passedCount)
        # echo buildTableNode[node[0].getName][bodyPos][0].repr
        # echo buildTableNode[node[0].getName][bodyPos][0].repr
        # buildTableNode[node[0].getName][bodyPos][0] = buildTableNode[node[0].getName][bodyPos][0][1]
        countNodeTable[node[0].getName] = passedCount
        countTableNode[node[0].getName] = 1
      else:
        let def = constructedTableNode[node[0].getName]
        let body = def[bodyPos][0]
        let passedCount = countNodeTable[node[0].getName]
        discard construct(monitor, parentElement, res,
                      count, textCount, body, isCall = true, passedCount)
      node.insert(1, newLit(count-1))
      # node.insert(2, monitor)
      # node.insert(3, parentElement)
      echo node.treeRepr
      result = quote do:
        `node`
      # else:
      #   result = quote do:
      #     `node`

      # res.add ""
      # result = newStmtList()

      # var currentNode =
      #   if count == 0:
      #     quote do:
      #       cast[Element](`parentElement`.firstChild) #! Node
      #   else:
      #     quote do:
      #       `parentElement`[`count`]
      # echo treeRepr(node)
      # let contextNode = ComponentContext(monitor: monitor,
      #                       parent: currentNode,
      #                       )

      # var newcall = newNimNode(nnkCall, node)
      # newcall.add node[0]
      # newcall.add contextNode

      # for i in 1..<node.len:
      #   newcall.add node[i]

      # result.add newcall
      # inc count
      # doAssert false, fmt"2: {name}"
      # result = newEmptyNode()
  else:
    doAssert false, fmt"3: {node.kind}"
    # if node.len > 0:
    #   for i in node:
    #     result = construct(i, res, content)
    # else:
    #   result = node

template build*(name, children: untyped): untyped =
  # echo children.treeRepr
  discard
  # let context = ident"componentContext
  #   construct(`context`.monitor,
  #     `context`.parent, `context`.res,
  #     `context`.count, # todo
  #     `context`.textCount, children)

macro buildHtml*(children: untyped): Element =
  echo children.treeRepr
  echo "++++++++++++++++++++++++++++++++++++++++++++"
  echo callSite().treeRepr
  echo "-----------------build----------------------"
  let parentElement = genSym(nskLet, "parentElement")
  var res = ""
  var count = 0
  var textCount = 0
  var monitor = genSym(nskVar, "monitor")
  let component = construct(monitor, parentElement, res, count, textCount, children)
  var defs = newStmtList()
  for i in buildTableNode.values:
    echo i.repr
    defs.add i
  # echo repr(component)
  # echo res
  result = quote do:
    var `monitor` {.global.} = Monitor() # todo remove global ?
    var fragment = document.createElement("template")
    fragment.innerHtml = `res`.cstring
    let `parentElement` {.global.} = fragment.content
    `defs`
    `component`
    apply(`monitor`)
    cast[Element](`parentElement`)

proc setRenderer*(render: proc(): Element, id = cstring"ROOT") =
  let root = document.getElementById(id)
  root.appendChild render()

