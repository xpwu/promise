package com.github.xpwu;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.ext.junit.runners.AndroidJUnit4;

import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.*;

/**
 * Instrumented test, which will execute on an Android device.
 *
 * @see <a href="http://d.android.com/tools/testing">Testing documentation</a>
 */
@RunWith(AndroidJUnit4.class)
public class ExampleInstrumentedTest {
  @Test
  public void useAppContext() {
    // Context of the app under test.
    Context appContext = InstrumentationRegistry.getInstrumentation().getTargetContext();
    assertEquals("com.github.xpwu", appContext.getPackageName());
  }

  @Test
  public void testPromise() {
    new Handler(Looper.getMainLooper()).post(this::promise);
  }

  private void promise() {

    FinalValue<Boolean> async = new FinalValue<>(false);

    Promise.resolve(10)
      .then(v -> {
        assertEquals((Integer) 10, v);
        assertEquals(true, async.value);

        return Promise.resolve(2).then(v1->Promise.resolve(v1+2));
      }).caught(error -> Promise.resolve(3))
      .then(v->{
        assertEquals((Integer) 4, v);
        return Promise.reject(new Error("test-error"));
      }).then(v->Promise.reject(new Error("not-test-error")))
      .caught(error->{
        assertEquals("test-error", error.getMessage());
        return Promise.reject(error);
      });

    async.value = true;
  }
}