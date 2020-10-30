package com.github.xpwu;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.Collection;
import java.util.SortedMap;
import java.util.TreeMap;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Function;

public class Promise<Value> {

  @FunctionalInterface
  public interface Resolve<Value> {
    void run(Value value);

    default void run() {
      run(null);
    }
  }

  @FunctionalInterface
  public interface Reject extends Resolve<Error> {
    default void run() {
      run(new Error());
    }
  }

  public Promise(@NonNull BiConsumer<Resolve<Value>, Reject> task) {

    if (Looper.getMainLooper() != Looper.myLooper()) {
      throw new RuntimeException("Promise must be called in mainThread");
    }

    try {
      task.accept(this::doResolve, this::doReject);
    } catch (Exception e) {
      e.printStackTrace();
      this.doReject(new Error(e));
    }
  }

  @NonNull
  public static <Value> Promise<Value> reject(@NonNull Error error) {
    return new Promise<>((resolve, reject) -> reject.run(error));
  }

  @NonNull
  public static <Value> Promise<Value> resolve(@NonNull Value value) {
    return new Promise<>((resolve, reject) -> resolve.run(value));
  }

  @NonNull
  public static <Value> Promise<Value> resolve() {
    return new Promise<>((resolve, reject) -> resolve.run());
  }

  public <Next> Promise<Next> then(@NonNull Function<Value, Promise<Next>> task) {

    return new Promise<>((resolve, reject) -> {
      // 异步执行
      this.resolves_.add(value -> new Handler().post(()->{
        Promise<Next> retValue;
        try {
          // 这里返回的可能是 fulfilled or rejected 的promise
          retValue = task.apply(value);
        }catch (Exception e) {
          e.printStackTrace();
          retValue = Promise.reject(new Error(e));
        }

        retValue.resolves_.add(resolve::run);
        retValue.rejects_.add(reject::run);

        retValue.nextCall_.run();
      }));

      // 直接向下一级传递错误
      this.rejects_.add(reject::run);

      this.nextCall_.run();
    });
  }

  @FunctionalInterface
  public interface PendTask<Value, Next> {
    void run(Value value, Resolve<Next> resolve, Reject reject);
  }

  public <Next> Promise<Next> then(@NonNull PendTask<Value, Next> task) {
    return this.then(value -> new Promise<>(
      (resolve, reject) -> task.run(value, resolve, reject))
    );
  }

  public <Next> Promise<Next> thenByThread(@NonNull PendTask<Value, Next> task) {
    return this.then((value, resolve, reject) -> {
      Handler handler = new Handler();
      new Thread(() -> {
        try {
          task.run(value
            , next -> handler.post(() -> resolve.run(next))
            , error -> handler.post(() -> reject.run(error))
          );
        } catch (Exception e) {
          e.printStackTrace();
          handler.post(() -> reject.run(new Error(e)));
        }
      }).start();
    });
  }

  private Promise<Void> value(@NonNull Consumer<Value> task) {
    return this.then(value -> {
      task.accept(value);
      return Promise.resolve();
    });
  }

  // caught 并不产生新的值，而是传递之前的值，所以下一个的类型仍然是Value
  public Promise<Value> caught(@NonNull Function<Error, Promise<Value>> task) {

    return new Promise<>((resolve, reject) -> {
      // 异步执行
      this.rejects_.add(error -> new Handler().post(()->{
        Promise<Value> retValue;
        try {
          // 这里返回的可能是 fulfilled or rejected 的promise
          retValue = task.apply(error);
        }catch (Exception e) {
          e.printStackTrace();
          retValue = Promise.reject(new Error(e));
        }

        retValue.resolves_.add(resolve::run);
        retValue.rejects_.add(reject::run);

        retValue.nextCall_.run();
      }));

      // 直接向下一级传递值
      this.resolves_.add(resolve::run);

      this.nextCall_.run();
    });
  }

  // 与其他端的 finally 一样的意义
  public Promise<Value> fina(final Runnable task) {

    return new Promise<>((resolve, reject) -> {
      this.resolves_.add(value -> new Handler().post(()->{
        try {
          task.run();
        }catch (Exception e) {
          e.printStackTrace();
          reject.run(new Error(e));
        }

        resolve.run(value);
      }));

      this.rejects_.add(error -> new Handler().post(()->{
        try {
          task.run();
        }catch (Exception e) {
          e.printStackTrace();
          reject.run(new Error(e));
        }

        reject.run(error);
      }));

      this.nextCall_.run();
    });
  }

  @NonNull
  public static <Value> Promise<Value> race(@NonNull Collection<Promise<Value>> promises) {

    return new Promise<>((resolve, reject) -> {

      // 在node.js 12.16.1 环境下测试，如果是空的话，将会被挂起，不执行后续逻辑，不太合理
      // 这里返回一个 null 的值
      if (promises.isEmpty()) {
        resolve.run();
        return;
      }

      for (Promise<Value> promise : promises) {
        promise.value(resolve::run).caught(error -> {
          reject.run(error);
          return Promise.resolve();
        });
      }
    });
  }

  @NonNull
  public static <Value> Promise<Collection<Value>> all(@NonNull Collection<Promise<Value>> promises) {

    return new Promise<>((resolve, reject) -> {

      if (promises.isEmpty()) {
        resolve.run(new ArrayList<>());
        return;
      }

      SortedMap<Integer, Value>ret = new TreeMap<>();
      FinalValue<Integer> cnt = new FinalValue<>(promises.size());

      // 要注意执行与返回结果必须要一一对应
      int i = 0;
      for (Promise<Value> promise : promises) {
        final int index = i;
        promise.value(value -> {
          ret.put(index, value);
          cnt.value--;
          // 全部成功，才算成功
          if (cnt.value == 0) {
            resolve.run(ret.values());
          }
        }).caught(error -> {
          // 有任何一个错误，则认为整个错误
          reject.run(error);
          return Promise.reject(error);
        });
      }
      ++i;
    });
  }

  private void doResolve(Value value) {
    if (!pending) {
      return;
    }
    pending = false;

    this.nextCall_ = ()-> {
      for (Consumer<Value> r: this.resolves_) {
        r.accept(value);
      }
      this.resolves_.clear();
    };

    this.nextCall_.run();
  }

  private void doReject(Error error) {
    if (!pending) {
      return;
    }
    pending = false;

    this.nextCall_ = ()-> {
      for (Consumer<Error> r: this.rejects_) {
        r.accept(error);
      }
      this.rejects_.clear();
    };

    this.nextCall_.run();
  }

  private Collection<Consumer<Value>> resolves_ = new ArrayList<>();
  private Collection<Consumer<Error>> rejects_ = new ArrayList<>();

  private Runnable nextCall_ = ()->{};
  private boolean pending = true;
}
