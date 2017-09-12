// RUN: rm -rf %t
// RUN: mkdir -p %t
// RUN: %target-build-swift -swift-version 5 %s -o %t/a.out
//
// RUN: %target-run %t/a.out
// REQUIRES: executable_test

import StdlibUnittest

var ProtocolInitTestSuite = TestSuite("ProtocolInit")

func mustFail<T>(f: () -> T?) {
  if f() != nil {
    preconditionFailure("Didn't fail")
  }
}

protocol TriviallyConstructible {
  init(inner: LifetimeTracked)
}

enum E : Error { case X }

extension TriviallyConstructible {
  init(middle x: LifetimeTracked) {
    self.init(inner: x)
  }

  init?(failingMiddle x: LifetimeTracked, shouldFail: Bool) {
    if (shouldFail) {
      return nil
    }
    self.init(inner: x)
  }

  init(throwingMiddle x: LifetimeTracked, shouldThrow: Bool) throws {
    if (shouldThrow) {
      throw E.X
    }
    self.init(inner: x)
  }

  init(assignToSelf x: LifetimeTracked) {
    self = Self(inner: x)
  }
}

class TrivialClass : TriviallyConstructible {

  convenience init(outer x: LifetimeTracked) {
    self.init(middle: x)
  }

  convenience init?(failingOuter x: LifetimeTracked, shouldFail: Bool) {
    self.init(failingMiddle: x, shouldFail: shouldFail)
  }

  convenience init(throwingOuter x: LifetimeTracked, shouldThrow: Bool) throws {
    try self.init(throwingMiddle: x, shouldThrow: shouldThrow)
  }

  convenience init(delegates x: LifetimeTracked) {
    self.init(assignToSelf: x)
  }

  required init(inner tracker: LifetimeTracked) {
    self.tracker = tracker
  }

  let tracker: LifetimeTracked
}

ProtocolInitTestSuite.test("ProtocolInit_Trivial") {
  _ = TrivialClass(outer: LifetimeTracked(0))
  _ = TrivialClass(delegates: LifetimeTracked(0))
}

ProtocolInitTestSuite.test("ProtocolInit_Failable") {
  do {
    let result = TrivialClass(failingOuter: LifetimeTracked(1), shouldFail: false)
    assert(result != nil)
  }
  do {
    let result = TrivialClass(failingOuter: LifetimeTracked(2), shouldFail: true)
    assert(result == nil)
  }
}

ProtocolInitTestSuite.test("ProtocolInit_Throwing") {
  do {
    let result = try TrivialClass(throwingOuter: LifetimeTracked(4), shouldThrow: false)
  } catch {
    preconditionFailure("Expected no error")
  }

  do {
    let result = try TrivialClass(throwingOuter: LifetimeTracked(5), shouldThrow: true)
    preconditionFailure("Expected error")
  } catch {}
}

class TrivialSubclass : TrivialClass {}

func makeSubclass() -> TrivialClass {
  return TrivialSubclass(delegates: LifetimeTracked(0))
}

ProtocolInitTestSuite.test("ProtocolInit_Subclass") {
  let t = makeSubclass()
  assert(t is TrivialSubclass)
}

runAllTests()
