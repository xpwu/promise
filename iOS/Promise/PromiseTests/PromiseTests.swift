//
//  PromiseTests.swift
//  PromiseTests
//
//  Created by xpwu on 2020/10/30.
//

import XCTest
@testable import Promise

struct StrError: Error, LocalizedError {
  public init(_ str:String) {
    self.str_ = str;
  }
  
  public var errorDescription: String? {
    return str_;
  }
  
  private var str_:String
}

class promiseTests: XCTestCase {
  
  var expection: XCTestExpectation? = nil

  override func setUpWithError() throws {
    expection = self.expectation(description: "promise")
  }

  override func tearDownWithError() throws {
    expection = nil
  }

//  func testExample() throws {
//      // This is an example of a functional test case.
//      // Use XCTAssert and related functions to verify your tests produce the correct results.
//  }
  
  func testInitResolve() {

    let _ = Promise<String>{ (resolve, reject) in
      resolve("test")
      self.expection?.fulfill()
    }
    self.waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testInitReject() {
    let _ = Promise<String>{ (resolve, reject) in
      reject(StrError("test err."))
      self.expection?.fulfill()
    }
    self.waitForExpectations(timeout: 3, handler: nil)
  }
  
  func testAlways() {
    let _ = Promise<String> { (resolve, reject) in
      resolve("test")
    }.finally {
      self.expection?.fulfill()
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testResolve() {
    Promise<String>.resolve("test").then { (value)->Promise<Void> in
      self.expection?.fulfill()
      return Promise<Void>.resolve()
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testResolveVoid() {
    Promise<Void>.resolve().finally {
      self.expection?.fulfill();
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testThen() {
    let _ = Promise<String>.resolve("test").then { (value) -> Promise<Void> in
      XCTAssert(value=="test");
      self.expection?.fulfill();
      return Promise<Void>.resolve();
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testVoidThen(){
    let _ = Promise<Void>.resolve().then { () -> Promise<Void> in
      self.expection?.fulfill();
      return Promise<Void>.resolve();
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testCaught() {
    let _ = Promise<String>.reject(StrError("test")).catch { (error:Error) -> Promise<String> in
      XCTAssert(error.localizedDescription == "test");
      self.expection?.fulfill();
      return Promise<String>.resolve("test-caught");
    }
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testThenThen() {
    let _ = Promise<String>.resolve("test").then { (value) -> Promise<Void> in
      XCTAssert(value == "test");
      return Promise<Void>.resolve();
    }.then { () -> Promise<Void> in
      self.expection?.fulfill();
      
      return Promise<Void>.resolve();
    }
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testThenCaughtThen() {
    Promise<String>.resolve("test")
      .then { (value) -> Promise<Void> in
        XCTAssert(value == "test");
        return Promise<Void>.resolve();
      }.catch({ (error) -> Promise<Void> in
        XCTAssert(false);
        return Promise<Void>.resolve();
      }).then { () -> Promise<Void> in
      self.expection?.fulfill();
      
      return Promise<Void>.resolve();
    }
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testPendThen() {
    Promise<String>.resolve("test").then({ (value, resolve, reject) in
      resolve(value + "---then");
    }).then { (value) -> Promise<Void> in
      XCTAssert(value == "test---then");
      self.expection?.fulfill();
      return Promise<Void>.resolve();
    }
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testThenByThread() {
		Promise.resolve("test").thenByThread( { (value: String, resolve:(String)->Void, reject) in
			let ret = value + "---then"
			resolve(ret);
    }).then { value -> Promise<Void> in
      XCTAssert(value == "test---then");
      self.expection?.fulfill();
      return Promise<Void>.resolve();
    }
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
	
	func testThenByThread2() {
		Promise.resolve("test").thenByThread( { (value: String) -> String in
			let ret = value + "---then"
			return ret
		}).then { value -> Promise<Void> in
			XCTAssert(value == "test---then");
			self.expection?.fulfill();
			return Promise<Void>.resolve();
		}
		
		self.waitForExpectations(timeout: 3, handler: nil);
	}
  
  func testAll() {
    let p1 = Promise.resolve("test1").then { (value: String) -> Promise<String> in
     return Promise.resolve(value+"p1");
    }
    let p2 = Promise.resolve("test2").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p2");
    }
    
    Promise.all([p1, p2]).then { (values: [String]) -> Promise<Void> in
      XCTAssert(values[0] == "test1p1");
       XCTAssert(values[1] == "test2p2");
      
      return Promise<Void>.resolve();
    }.finally {
        self.expection?.fulfill();
    }
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func testAllTuple() {
    let p1 = Promise.resolve("test1").then { (value: String) -> Promise<Int> in
      return Promise.resolve(10);
    }
    let p2 = Promise.resolve("test2").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p2");
    }
    
    Promise.all(p1, p2).then({ (arg) -> Promise<Void> in
      let (v1, v2) = arg
      XCTAssert(v1 == 10);
      XCTAssert(v2 == "test2p2");
      
      return Promise<Void>.resolve();
    }).finally {
      self.expection?.fulfill();
    };
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }
  
  func test6Tuple() {
    let p1 = Promise.resolve("test1").then { (value: String) -> Promise<Int> in
      XCTAssert(value == "test1");
      return Promise.resolve(10);
    }
    let p2 = Promise.resolve("test2").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p2");
    }
    let p3 = Promise.resolve("test3").then { (value: String) -> Promise<Int> in
      XCTAssert(value == "test3");
      return Promise.resolve(50);
    }
    let p4 = Promise.resolve("test4").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p4");
    }
    let p5 = Promise.resolve("test5").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p5");
    }
    let p6 = Promise.resolve("test6").then { (value: String) -> Promise<String> in
      return Promise.resolve(value+"p6");
    }
    
    Promise.all(p1, p2, p3, p4, p5, p6).then({ (arg) -> Promise<Void> in
      let (v1, v2, v3, v4, v5, v6) = arg
      XCTAssert(v1 == 10);
      XCTAssert(v2 == "test2p2");
      XCTAssert(v3 == 50);
      XCTAssert(v4 == "test4p4");
      XCTAssert(v5 == "test5p5");
      XCTAssert(v6 == "test6p6");
      
      return Promise<Void>.resolve();
    }).finally {
      self.expection?.fulfill();
    };
    
    self.waitForExpectations(timeout: 3, handler: nil);
  }

//  func testPerformanceExample() throws {
//      // This is an example of a performance test case.
//      self.measure {
//          // Put the code you want to measure the time of here.
//      }
//  }

}
