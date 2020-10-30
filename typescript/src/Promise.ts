
export class Promise<Value> {

  constructor(task: (resolve:(value:Value)=>void, reject:(error: Error)=>void)=>void) {
    try {
      task(value => {
        this.doResolve(value);
      }, error => {
        this.doReject(error);
      });
    }catch (e) {
      console.error(e)
      this.doReject(e)
    }
  }

  public static reject<Value> (err:Error): Promise<Value> {
    return new Promise<Value>((resolve, reject)=>{
      reject(err);
    })
  }

  public static resolve (): Promise<void>;
  public static resolve<Value> (value: Value): Promise<Value>;
  static resolve (...values:any[]): Promise<any>{
    return new Promise((resolve, reject)=>{
      resolve(values[0]);
    })
  }

  public then<Next> (task: (value:Value)=>Promise<Next>|Next): Promise<Next> {
    return new Promise<Next>((resolve, reject)=>{

      this.resolves_.push((value)=>{
        setTimeout(()=>{
          let retValue: Promise<Next>;
          try {
            let ret = task(value);
            if (ret instanceof Promise) {
              retValue = ret;
            } else {
              retValue = Promise.resolve(ret);
            }
          }catch (e) {
            console.error(e);
            retValue = Promise.reject(e);
          }

          retValue.resolves_.push(resolve);
          retValue.rejects_.push(reject);

          retValue.nextCall_();
        }, 0);
      })

      this.rejects_.push(reject);

      this.nextCall_();
    })
  }

  public catch (task: (err:Error)=>Promise<Value>|Value): Promise<Value> {
    return new Promise<Value>((resolve, reject)=>{

      this.rejects_.push((err)=>{
        setTimeout(()=>{
          let retValue: Promise<Value>;
          try {
            let ret = task(err);
            if (ret instanceof Promise) {
              retValue = ret;
            } else {
              retValue = Promise.resolve(ret);
            }
          }catch (e) {
            console.error(e);
            retValue = Promise.reject(e);
          }

          retValue.resolves_.push(resolve);
          retValue.rejects_.push(reject);

          retValue.nextCall_();
        }, 0);
      })

      this.resolves_.push(resolve);

      this.nextCall_();
    })
  }

  public finally(task:()=>void): Promise<Value> {
    return new Promise<Value>((resolve, reject)=>{
      this.resolves_.push(value=>{
        setTimeout(()=>{
          try {
            task();
          }catch (e) {
            console.error(e);
            reject(e);
          }

          resolve(value);
        }, 0);
      })

      this.rejects_.push(err=>{
        setTimeout(()=>{
          try {
            task();
          }catch (e) {
            console.error(e);
            reject(e);
          }

          reject(err);
        }, 0);
      })

      this.nextCall_();
    })
  }

  public static race<Value> (promises:Promise<Value>[]): Promise<Value|void> {
    return new Promise<Value|void>((resolve, reject)=>{
      if (promises.length == 0) {
        resolve();
        return
      }

      for (const promise of promises) {
        promise.then(value => {
          resolve(value);
        }).catch(err => {
          reject(err);
        })
      }
    });
  }

  public static all<T1, T2, T3, T4, T5, T6>(
    promises: [Promise<T1>, Promise<T2>, Promise<T3>, Promise<T4>, Promise<T5>, Promise<T6>])
    : Promise<[T1, T2, T3, T4, T5, T6]>;
  public static all<T1, T2, T3, T4, T5>(
    promises: [Promise<T1>, Promise<T2>, Promise<T3>, Promise<T4>, Promise<T5>]): Promise<[T1, T2, T3, T4, T5]>;
  public static all<T1, T2, T3, T4>(
    promises: [Promise<T1>, Promise<T2>, Promise<T3>, Promise<T4>]): Promise<[T1, T2, T3, T4]>;
  public static all<T1, T2, T3>(Promises: [Promise<T1>, Promise<T2>, Promise<T3>]): Promise<[T1, T2, T3]>;
  public static all<T1, T2>(promises: [Promise<T1>, Promise<T2>]): Promise<[T1, T2]>;
  public static all<Value>(Promises: Promise<Value>[]):Promise<Value[]>;

  public static all(promises: Promise<any>[]): Promise<any> {
    return this._all(promises);
  }

  private static _all<Value> (promises: Promise<Value>[]): Promise<Value[]> {
    return new Promise<Value[]>((resolve, reject)=>{
      if (promises.length == 0) {
        resolve([]);
        return;
      }

      let cnt = promises.length;
      let ret = new Array<Value>(promises.length);

      // 要注意执行与返回结果必须要一一对应
      for (let i = 0; i < promises.length; ++i) {
        promises[i].then(value => {
          ret[i] = value;
          cnt--;
          // 全部成功，才算成功
          if (cnt == 0) {
            resolve(ret);
          }
        }).catch(err => {
          // 有任何一个错误，则认为整个错误
          reject(err)
        })
      }
    })
  }

  private doResolve(value: Value):void {
    if (!this.pending) {
      return;
    }
    this.pending = false;

    this.nextCall_ = ()=>{
      for (let r of this.resolves_) {
        r(value)
      }

      this.resolves_ = []
    }

    this.nextCall_();
  }

  private doReject(err: Error):void {
    if (!this.pending) {
      return;
    }
    this.pending = false;

    this.nextCall_ = ()=>{
      for (let r of this.rejects_) {
        r(err)
      }

      this.rejects_ = []
    }

    this.nextCall_();
  }

  private resolves_:((v:Value)=>void)[] = []
  private rejects_:((e:Error)=>void)[] = []

  private nextCall_ = ()=>{};
  private pending = true;
}
