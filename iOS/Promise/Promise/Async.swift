//
//  Promise.swift
//  promise
//
//  Created by xpwu on 2020/9/27.
//

import Foundation


public class Async:NSObject {
  
  public  override init(){}
  
  public func run(_ runner:@escaping ()->Void ) {
    self.runner_ = runner;
    
    self.perform(#selector(selector), with: nil, afterDelay: 0);
  }
  
  @objc func selector() {
    self.runner_();
  }
  
  private var runner_: (()->Void)!;
}

