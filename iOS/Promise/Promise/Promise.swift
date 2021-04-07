//
//  Promise.swift
//  promise
//
//  Created by xpwu on 2020/9/27.
//

// NOTE THAT:  目前调用的情况  Promise<Value> 中的Value 必须能推断出来，为了调用的方便，
// 所有静态方法中的泛型名 都是用 Value 名字

import Foundation

public class Promise<Value> {
  
  public init(_ task: (@escaping (Value)->Void, @escaping (Error)->Void )throws->Void) {
    if Thread.current != Thread.main {
      fatalError("Promise.init(...) must be called in mainThread");
    }
    
    do {
      try task({self.doResolve($0)}, {self.doReject($0)})
    }catch {
      doReject(error)
    }
  }
  
  static public func reject (_ err:Error)->Promise<Value> {
    return Promise<Value>({$1(err)});
  }
  
  static public func resolve(_ value:Value)->Promise<Value> {
    return Promise{(resolve:(Value)->Void, reject:(Error)->Void) in resolve(value)}
  }
  
  static public func resolve()->Promise<Void> {
    return Promise<Void>.resolve(())
  }
  
  @discardableResult
  public func then<Next> (_ task:@escaping (Value)throws->Promise<Next>)->Promise<Next> {
    return Promise<Next>{
      (resolve:@escaping (Next)->Void, reject:@escaping (Error)->Void)->Void in
      self.resolves.append({value in
        Async().run {
          var retValue:Promise<Next>
          do {
            // 这里返回的可能是 fulfilled or rejected 的promise
            retValue = try task(value)
          }catch {
            retValue = Promise<Next>.reject(error)
          }
          
          retValue.resolves.append(resolve)
          retValue.rejects.append(reject)
          
          retValue.nextCall()
        }
      })
      
      self.rejects.append(reject)
      
      self.nextCall()
    }
  }
  
  @discardableResult
  public func then<Next> (_ task:@escaping (Value, @escaping (Next)->Void
    , @escaping (Error)->Void)throws->Void)->Promise<Next> {
    
    return self.then {value in Promise<Next>(){
      (resolve, reject) in
      try task(value, resolve, reject)
    }}
  }
  
  @discardableResult
  public func thenByThread<Next> (_ task:@escaping (Value, @escaping (Next)->Void
    , @escaping (Error)->Void)throws->Void)->Promise<Next> {

    return self.then {(value, resolve, reject) in
      let thread = Thread();
      thread.setRunner{
        do {
          try task(value, {next in thread.postBack{resolve(next)} }
                   , {err in thread.postBack{reject(err)} }
          );
        } catch {
          thread.postBack{reject(error)}
        }
      }.start()
      
    }
  }
  
  private func value(_ task: @escaping (Value)throws->Void)->Promise<Void> {
    self.then{ value->Promise<Void> in
      try task(value)
      return Promise.resolve()
    }
  }
  
  @discardableResult
  public func `catch`(_ task:@escaping (Error)throws->Promise<Value>)->Promise<Value> {
    return Promise<Value>(){
      (resolve:@escaping (Value)->Void, reject:@escaping (Error)->Void)->Void in
      self.rejects.append({err in
        Async().run {
          var retValue:Promise<Value>
          do {
            // 这里返回的可能是 fulfilled or rejected 的promise
            retValue = try task(err)
          }catch {
            retValue = Promise.reject(error)
          }
          
          retValue.resolves.append(resolve)
          retValue.rejects.append(reject)
          
          retValue.nextCall()
        }
      })
      
      self.resolves.append(resolve)
      
      self.nextCall()
    }
  }
  
  @discardableResult
  public func finally (_ task:@escaping ()throws->Void)->Promise<Value> {
    return Promise<Value>(){
      (resolve:@escaping (Value)->Void, reject:@escaping (Error)->Void)->Void in
      self.rejects.append({err in
        Async().run {
          do {
            try task()
          }catch {
            reject(error)
          }
          
          reject(err)
        }
      })
      
      self.resolves.append({value in
        Async().run {
          do {
            try task()
          }catch {
            reject(error)
          }
          
          resolve(value)
        }
      })
      
      self.nextCall()
    }
  }
  
  static public func race (_ promises: [Promise<Value>])->Promise<Value?> {
    return Promise<Value?>{ (resolve, reject) in
      // 在node.js 12.16.1 环境下测试，如果是空的话，将会被挂起，不执行后续逻辑，不太合理
      // 这里返回一个 nil 的值
      if promises.isEmpty {
        resolve(nil)
        return;
      }
      
      for promise in promises {
        promise.value{
          resolve($0)
        }.catch{ error in
          reject(error)
          return Promise.resolve()
        }
      }
    }
  }
  
  static public func all (_ promises: [Promise<Value>])->Promise<[Value]> {
    return Promise<[Value]> { (resolve, reject) in
      
      if promises.isEmpty {
        resolve([Value]())
      }
      
      var ret = [Int:Value]()
      var cnt = promises.count
      
      for i in 0..<promises.count {
        promises[i].value{
          ret[i] = $0
          cnt -= 1
          if (cnt == 0) {
            var temp = [Value]()
            for j in 0 ..< ret.count {
              temp.append(ret[j]!)
            }
            resolve(temp)
          }
        }.catch{ error in
          reject(error)
          return Promise.resolve()
        }
      }
    }
  }
  
  private func doResolve(_ value:Value)->Void {
    if !self.pending {
      return
    }
    self.pending = false
    
    self.nextCall = {[unowned self] in
      for r in self.resolves {
        r(value)
      }
      self.resolves = []
    }
    
    self.nextCall()
  }
  
  private func doReject(_ err:Error)->Void {
    if !self.pending {
      return
    }
    self.pending = false
    
    self.nextCall = {[unowned self] in
      for r in self.rejects {
        r(err)
      }
      self.rejects = []
    }
    
    self.nextCall()
  }
  
  private var resolves:[(_ v:Value)->Void] = []
  private var rejects:[(_ err:Error)->Void] = []
  
  private var nextCall = {()->Void in }
  private var pending = true;
}

// tuple all
extension Promise {
  static public func all<T2>(_ promise1: Promise<Value>, _ promise2: Promise<T2>)
    ->Promise<(Value, T2)> {
    var ret: (_1:Value?, _2:T2?) = (nil, nil)
    
    return Promise<Void>.all([promise1.value{ret._1 = $0}
                              , promise2.value{ret._2 = $0}])
      .then{ (_)->Promise<(Value, T2)> in
      return Promise<(Value, T2)>.resolve((ret._1!, ret._2!))
    }
  }
  
  static public func all<T2, T3>(_ promise1: Promise<Value>, _ promise2: Promise<T2>
    , _ promise3: Promise<T3>)->Promise<(Value, T2, T3)> {
    var ret: (_1:Value?, _2:T2?, _3:T3?) = (nil, nil, nil)
    
    return Promise<Void>.all([promise1.value{ret._1 = $0}
                              , promise2.value{ret._2 = $0}
                              , promise3.value{ret._3 = $0}])
      .then{ (_)->Promise<(Value, T2, T3)> in
        return Promise<(Value, T2, T3)>.resolve((ret._1!, ret._2!, ret._3!))
    }
  }
  
  static public func all<T2, T3, T4>(_ promise1: Promise<Value>, _ promise2: Promise<T2>
    , _ promise3: Promise<T3>, _ promise4: Promise<T4>)->Promise<(Value, T2, T3, T4)> {
    var ret: (_1:Value?, _2:T2?, _3:T3?, _4:T4?) = (nil, nil, nil, nil)
    
    return Promise<Void>.all([promise1.value{ret._1 = $0}
                              , promise2.value{ret._2 = $0}
                              , promise3.value{ret._3 = $0}
                              , promise4.value{ret._4 = $0}])
      .then{ (_)->Promise<(Value, T2, T3, T4)> in
        return Promise<(Value, T2, T3, T4)>.resolve((ret._1!, ret._2!, ret._3!, ret._4!))
    }
  }
  
  static public func all<T2, T3, T4, T5>(_ promise1: Promise<Value>, _ promise2: Promise<T2>
    , _ promise3: Promise<T3>, _ promise4: Promise<T4>
    , _ promise5: Promise<T5>)->Promise<(Value, T2, T3, T4, T5)> {
    var ret: (_1:Value?, _2:T2?, _3:T3?, _4:T4?, _5:T5?) = (nil, nil, nil, nil, nil)
    
    return Promise<Void>.all([promise1.value{ret._1 = $0}
                              , promise2.value{ret._2 = $0}
                              , promise3.value{ret._3 = $0}
                              , promise4.value{ret._4 = $0}
                              , promise5.value{ret._5 = $0}])
      .then{ (_)->Promise<(Value, T2, T3, T4, T5)> in
        return Promise<(Value, T2, T3, T4, T5)>.resolve((ret._1!, ret._2!, ret._3!, ret._4!, ret._5!))
    }
  }
  
  static public func all<T2, T3, T4, T5, T6>(_ promise1: Promise<Value>
    , _ promise2: Promise<T2>, _ promise3: Promise<T3>
    , _ promise4: Promise<T4>, _ promise5: Promise<T5>
    , _ promise6: Promise<T6>)->Promise<(Value, T2, T3, T4, T5, T6)> {
    var ret: (_1:Value?, _2:T2?, _3:T3?, _4:T4?, _5:T5?, _6:T6?) = (nil, nil, nil, nil, nil, nil)
    
    return Promise<Void>.all([promise1.value{ret._1 = $0}
                              , promise2.value{ret._2 = $0}
                              , promise3.value{ret._3 = $0}
                              , promise4.value{ret._4 = $0}
                              , promise5.value{ret._5 = $0}
                              , promise6.value{ret._6 = $0}])
      .then{ (_)->Promise<(Value, T2, T3, T4, T5, T6)> in
        return Promise<(Value, T2, T3, T4, T5, T6)>.resolve((ret._1!, ret._2!, ret._3!, ret._4!, ret._5!, ret._6!))
    }
  }
}

