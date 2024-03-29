// 通过出生日期计算年龄
// console.log(getAge('2001-01-01'))
// console.log(getAge('2001-01-01', '2022-12-26'))
export function getAge(birthday, lastDay = null) {
  if (typeof birthday === "string" && /^(\d+-\d+-\d+)/.test(birthday)) {
    if (typeof lastDay !== "string" || !/^(\d+-\d+-\d+)/.test(lastDay)) {
      let d = new Date();
      lastDay = `${d.getFullYear()}-${(d.getMonth() + 1) <= 9 ? '0' + (d.getMonth() + 1) : (d.getMonth() + 1)}-${d.getDate() <= 9 ? '0' + d.getDate() : d.getDate()}`
    }
    try {
      birthday = birthday.replace(/\s.*/g, '');
      lastDay = lastDay.replace(/\s.*/g, '');
      birthday = birthday.split('-');
      lastDay = lastDay.split('-');
      if (lastDay[0] - birthday[0] <= 0) {
        return 0;
      }
      let diffBirthday = Number(birthday[1]) + '' + birthday[2];
      let diffLastDay = Number(lastDay[1]) + '' + lastDay[2];
      if (Number(diffBirthday) <= Number(diffLastDay)) {
        return lastDay[0] - birthday[0];
      }
      return (lastDay[0] - birthday[0]) - 1;
    } catch (error) {
      return 0;
    }
  }
  return 0;
}

// 字符串超出省略号显示
// console.log(stringEllipsis('字符串省略号显示字符串省略号显示', 5)) // 字符串省略...
// console.log(stringEllipsis('字符串省略号显示字符串省略号显示', -1)) // 字符串省略号显示字符串省略号显示
export function stringEllipsis(txt, num, tag = '...') {
    txt = JSON.stringify(txt || '').replace(/[\'\"]/g, "");
    num = Number(num) || -1;
    if (txt.length > num && num >= 0) {
        return txt.substring(0, num) + tag;
    }
    return txt;
}

// 身份信息脱敏处理 
// console.log(hideCode(13015899696, 3, 4)) // 130****9696
// console.log(hideCode(13015899696, -1, -1)) // 13015899696
export function hideCode(str, frontLen, endLen, tag = '*') {
    str = JSON.stringify(str || '').replace(/[\'\"]/g, "");
    let len = str.length - Number(frontLen || 0) - Number(endLen || 0);
    let xing = '';
    for (let i = 0; i < len; i++) {
        xing += tag;
    }
    if (str.length >= (frontLen + endLen)) {
        return str.substring(0, frontLen) + xing + str.substring(str.length - endLen);
    }
    return str;
}

// 前端获取url地址中的参数
// console.log(getUrlParams())  //  结果  {name: '88', age: '88'}
export function getUrlParams() {
    let params = {};
    let query = "";
    try {
        query = window.location.href.replace(/.*\?/, "");
    } catch (e) {
        query = "";
    }
    let tempVar = query.split("&");
    for (let k in tempVar) {
        params[tempVar[k].split('=')[0]] = tempVar[k].split('=')[1];
    }
    return params;
}

// 数组分类函数，通过函数获得key
// console.log(groupArray(tempArr, (item) => item.age + '-' + item.sex))
export function groupArray(tempArr, getKey) {
    let result = {}
    if (typeof getKey == 'string') {
        let tempKey = getKey;
        getKey = function (item) { return item[tempKey] }
    }
    for (let i in tempArr) {
        let key = getKey(tempArr[i])
        if (!result[key]) {
            result[key] = [];
        }
        result[key].push(tempArr[i])
    }
    return result;
}

// 数据加密方法
// console.log(Decode(Encode([1,8,9,{name:'张三'}],8),-8));
export function Encode(strJson, salt) {
    let strArr = JSON.stringify(strJson);
    let res = [];
    for (let i in strArr) {
        res[i] = strArr.charCodeAt(i) + salt;
    }
    return JSON.stringify(res);
}

// 数据解密方法
// console.log(Decode(Encode([1,8,9,{name:'张三'}],8),-8));
export function Decode(strJson, salt) {
    let strArr = JSON.stringify(strJson).replace(/[\[|\]|\"|\']/g, '').split(',');
    let res = "";
    for (let i in strArr) {
        res += String.fromCharCode(Number(strArr[i]) + salt);
    }
    return JSON.parse(res);
}

// 数组去重函数
// let tempArrObj = [{ name: '张三', age: 15, sex: 5 }, { name: '李四', age: 12, sex: 1 }, { name: '王五', age: 15, sex: 5 }, { name: '张三', age: 12, sex: 1 }, { name: '李四', age: 15, sex: 1 }];
// console.log(remRepeat(tempArrObj, (a, b) => { return a.name == b.name }));
export function remRepeat(tempArr, ifFun) {
    let newTempArr = [];
    for (let i in tempArr) {
        if (i === '0') { newTempArr[0] = tempArr[0]; }
        for (let j in newTempArr) {
            if (ifFun(tempArr[i], newTempArr[j])) {
                break;
            }
            if (j == newTempArr.length - 1) {
                newTempArr.push(tempArr[i]);
            }
        }
    }
    return newTempArr;
}

// 通过时间戳转换为日期格式
// console.log(timestampToDate(new Date().getTime()))
// console.log(timestampToDate(new Date().getTime(), (v) => { return v.Y + '年' + v.M + '月' + v.D + '日' + ' ' + v.h + '时' + v.m + '分' + v.s + '秒' }))
export function timestampToDate(timestamp, formatFun = null) {
    if ((timestamp + '').length == 10) {
        timestamp = timestamp * 1000;
    }
    let date = new Date(timestamp);
    let result = {};
    result.Y = (date.getFullYear() + '');
    result.M = completion(date.getMonth() + 1);
    result.D = completion(date.getDate());
    result.h = completion(date.getHours());
    result.m = completion(date.getMinutes());
    result.s = completion(date.getSeconds());
    function completion(num) {
        num = num.toString();
        return num[1] ? num : '0' + num;
    }
    if (formatFun == null) {
        return result.Y + '-' + result.M + '-' + result.D + ' ' + result.h + ':' + result.m + ':' + result.s;
    }
    return formatFun(result)
}

// 通过日期获取当前周的所有日期
// console.log(getWeekList())
// console.log(getWeekList('2022-12-31'))
// console.log(getWeekList('2022-12-31', '/'))
export function getWeekList(tempDate = null, tag = '-') {
    let weekList = [];
    let date = tempDate ? new Date(tempDate) : new Date();
    if (date.getDay() == "0") {
        date.setDate(date.getDate() - 6);
    } else {
        date.setDate(date.getDate() - date.getDay() + 1);
    }
    let myDate = completion(date.getDate());
    let myMonth = completion(date.getMonth() + 1);
    weekList.push(date.getFullYear() + tag + myMonth + tag + myDate);
    for (let i = 0; i < 6; i++) {
        date.setDate(date.getDate() + 1);
        myDate = completion(date.getDate());
        myMonth = completion(date.getMonth() + 1);
        weekList.push(date.getFullYear() + tag + myMonth + tag + myDate);
    }
    function completion(num) {
        num = num.toString();
        return num[1] ? num : '0' + num;
    }
    return weekList;
}

// 设置页面缓存 console.log(setPageCache('test',{name:'张三'}))
export function setPageCache(page, value) {
    let result = {}
    if (typeof page !== "string") {
        page = JSON.stringify(page)
    }
    try {
        result = JSON.parse(sessionStorage[page]);
    } catch (error) {
        result = '';
    }
    if (value && result && typeof value === "object" && typeof result === 'object') {
        for (let i in value) {
            result[i] = value[i];
        }
    } else {
        result = value ? value : '';
    }
    sessionStorage[page] = JSON.stringify(result);
    return true;
}

// 获取页面缓存 console.log(getPageCache('test'))
export function getPageCache(page) {
    if (typeof page !== "string") {
        page = JSON.stringify(page)
    }
    let result = {};
    try {
        result = JSON.parse(sessionStorage[page]);
    } catch (error) {
        result = '';
    }
    return result;
}

// base64图片转file的方法（base64图片, 设置生成file的文件名）
export function base64ToFile(base64, fileName) {
    // 将base64按照 , 进行分割 将前缀  与后续内容分隔开
    const data = base64.split(',');
    // 利用正则表达式 从前缀中获取图片的类型信息（image/png、image/jpeg、image/webp等）
    const type = data[0].match(/:(.*?);/)[1];
    // 从图片的类型信息中 获取具体的文件格式后缀（png、jpeg、webp）
    const suffix = type.split('/')[1];
    // 使用atob()对base64数据进行解码  结果是一个文件数据流 以字符串的格式输出
    const bstr = window.atob(data[1]);
    // 获取解码结果字符串的长度
    let n = bstr.length
    // 根据解码结果字符串的长度创建一个等长的整形数字数组
    // 但在创建时 所有元素初始值都为 0
    const u8arr = new Uint8Array(n)
    // 将整形数组的每个元素填充为解码结果字符串对应位置字符的UTF-16 编码单元
    while (n--) {
        // charCodeAt()：获取给定索引处字符对应的 UTF-16 代码单元
        u8arr[n] = bstr.charCodeAt(n)
    }
    // 利用构造函数创建File文件对象
    // new File(bits, name, options)
    const file = new File([u8arr], `${fileName}.${suffix}`, {
        type: type
    })
    // 将File文件对象返回给方法的调用者
    return file;
}

// vue2 初始化组件中data值
export function vueInitData(that, key = '') {
  let runStr = `Object.assign(that.$data,that.$options.data());`;
  if (typeof key === 'string' && key) {
    runStr = `that.${key} = that.$options.data().${key};`;
  }
  new Function('that', `${runStr};`)(that);
}

// 深度赋值json对象或者数组
export function deepCopy(obj) {
  var result = Array.isArray(obj) ? [] : {};
  for (var key in obj) {
    if (obj.hasOwnProperty(key)) {
      if (typeof obj[key] === 'object' && obj[key] !== null) {
        result[key] = deepCopy(obj[key]);   //递归复制
      } else {
        result[key] = obj[key];
      }
    }
  }
  return result;
}

// blob 格式下载
export function downloadBlobFn(blob, downloadValue) { 
    const a = document.createElement('a')
    a.href = window.URL.createObjectURL(blob)
    a.download = downloadValue // downloadValue为下载文件的名字，在函数外处理好再传传进来
    a.textContent = 'export data'
    a.style.textIndent = '-1000px'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
}

// url 格式下载
export function downloadUrlFn(url, downloadValue) { 
    var a = document.createElement('a')
    a.href = url
    a.download = downloadValue // downloadValue为下载文件的名字，在函数外处理好再传传进来
    a.textContent = 'export data'
    a.style.textIndent = '-1000px'
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
}

// 表单校验提示封装
// console.log(checkFormFn([{ fun: () => { return true; }, hint: "用户名不能为空！" }]))
export function checkFormFn(params, funKey = 'fun', hintKey = "hint") {
  if (typeof params === "object" && typeof funKey === "string" && typeof hintKey === "string") {
    for (let i in params) {
      if (params[i][funKey]()) {
        return params[i][hintKey];
      }
    }
  }
  return '';
}
