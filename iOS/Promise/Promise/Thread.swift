//
//  Promise.swift
//  promise
//
//  Created by xpwu on 2020/9/27.
//

import Foundation

public class Thread: Foundation.Thread {
  private class Current: NSObject {
    @objc func selector()->Void {
      self.runner_();
    }
    
    public func setRunner(_ runner:@escaping ()->Void)->Void {
      self.runner_ = runner;
      self.perform(#selector(selector), on: self.current_
        , with: nil, waitUntilDone: false);
    }
    
    init(_ current: Foundation.Thread) {
      self.current_ = current;
    }
    
    private var runner_ = {()->Void in };
    private let current_: Foundation.Thread;
  }
  
  public func postBack(_ task:@escaping ()->Void) ->Void {
    self.current_.setRunner(task);
  }
  
  override init() {
    self.current_ = Current(Foundation.Thread.current);
  }
  
  public func setRunner(_ main:@escaping ()->Void)->Thread {
    self.main_ = main;
    return self;
  }
  
  public override func main() {
    main_();
  }
  
  private var main_ = {()->Void in };
  private let current_:Current;
}


