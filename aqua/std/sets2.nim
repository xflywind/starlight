type
  Set*[T] = ref object


func newJSet*[T](): Set[T] {.importjs: "new Set()".}
proc add*[T](s: Set[T]; x: T) {.importjs: "#.add(#)".}
proc contains*[T](s: Set[T]; x: T): bool {.importjs: "#.has(#)".}
proc len*[T](s: Set[T]): int {.importjs: "#.size".}
proc delete*[T](s: Set[T]; x: T) {.importjs: "#.delete(#)".}

iterator items*[T](d: Set[T]): T =
  var kkk: T
  {.emit: ["for (const ", kkk, " of ", d, ") {"].}
  yield kkk
  {.emit: ["}"].}
