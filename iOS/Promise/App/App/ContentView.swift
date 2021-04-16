//
//  ContentView.swift
//  App
//
//  Created by xpwu on 2021/4/16.
//

import SwiftUI
import Promise

struct StrError: Error, LocalizedError {
  public init(_ str:String) {
    self.str_ = str;
  }
  
  public var errorDescription: String? {
    return str_;
  }
  
  private var str_:String
}

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
      Button(action: {
        print("\n...")
        Promise{ (resolve:@escaping (Int)->Void, reject:@escaping (Error)->Void) in
           Timer.scheduledTimer(withTimeInterval: 1, repeats: false) {
            (_ Timer) in resolve(10)}
        }.then { (a: Int) -> Promise<Int> in
          print(a)
          return Promise.reject(StrError("error"))
        }.catch { (err: Error) -> Promise<Int> in
          print(err)
          return Promise.reject(err)
        }
      }, label: {
        Text("测试")
      })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
