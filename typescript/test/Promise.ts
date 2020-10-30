import {Promise} from "../src/Promise";

Promise.resolve().then(v=>{
  console.info(v);
  return 10;
}).then(v=>{
  console.info(v);
  return new Promise((resolve, reject)=>{
    setTimeout(()=>{resolve(5)}, 0)
  })
}).catch(err=>{
  console.error(err);
  return Promise.reject(Error("err1"));
}).then(v=>{
  console.info(v);
  return Promise.reject(Error("err2"));
}).catch(err=>{
  // 这里应该输出错误，并且能看到错误产生的原始文件及行号
  console.error(err);
})
