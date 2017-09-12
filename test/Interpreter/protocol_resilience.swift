// RUN: %empty-directory(%t)

// RUN: %target-build-swift -emit-module -parse-as-library -Xfrontend -enable-resilience %S/../Inputs/resilient_protocol.swift -emit-module-path %t/resilient_protocol.swiftmodule -module-name resilient_protocol -emit-library -o %t/libresilient_protocol.%target-dylib-extension
// RUN: %target-build-swift %s -lresilient_protocol -I %t -L %t -o %t/main -Xlinker -rpath -Xlinker %t
// RUN: %target-codesign %t/libresilient_protocol.%target-dylib-extension
// RUN: %target-run %t/main

// RUN: %target-build-swift -emit-module -parse-as-library -Xfrontend -enable-resilience %S/../Inputs/resilient_protocol.swift -emit-module-path %t/resilient_protocol.swiftmodule -module-name resilient_protocol -emit-library -o %t/libresilient_protocol.%target-dylib-extension -whole-module-optimization
// RUN: %target-build-swift %s -lresilient_protocol -I %t -L %t -o %t/main -Xlinker -rpath -Xlinker %t
// RUN: %target-codesign %t/libresilient_protocol.%target-dylib-extension
// RUN: %target-run %t/main

// REQUIRES: executable_test

//
// Note: protocol resilience in the sense of resiliently adding new
// requirements with default implementations is actually tested in
// validation-test/Evolution/test_protocol_*.
//

import StdlibUnittest


import resilient_protocol

var ResilientProtocolTestSuite = TestSuite("ResilientProtocol")

func increment(_ x: inout Int, by: Int) {
  x += by
}

struct OtherConformingType : OtherResilientProtocol { }

// Ensure we can call materializeForSet defined in a protocol extension
// from a different resilience domain.
ResilientProtocolTestSuite.test("PropertyInProtocolExtension") {
  var o = OtherConformingType()

  increment(&o.propertyInExtension, by: 5)
  increment(&OtherConformingType.staticPropertyInExtension, by: 7)

  expectEqual(OtherConformingType.staticPropertyInExtension, 12)
}

struct DerivedConformingType : ResilientDerivedProtocol {
  func requirement() -> Int { return 42 }
}

// Ensure dynamic casts to resilient types work.
func callBaseRequirement(t: ResilientBaseProtocol) -> Int {
  return t.requirement()
}

@_semantics("optimize.sil.never")
func castToDerivedProtocol<T>(t: T) -> Int {
  return callBaseRequirement(t: t as! ResilientDerivedProtocol)
}

ResilientProtocolTestSuite.test("DynamicCastToResilientProtocol") {
  expectEqual(castToDerivedProtocol(t: DerivedConformingType()), 42)
}

runAllTests()
