// 通过出生日期计算年龄
// console.log(getAge('2001-01-01'))
export function getAge(birthday = '1999-01-01') {
    if (typeof birthday == 'string') {
        birthday = birthday.replace(/\s.*/g, '');
        let result = ((new Date() - new Date(birthday)) / (24 * 60 * 60 * 1000 * 365) + '').split('.');
        if (Number(result[0]) >= 1) {
            return Number(result[0]);
        }
        return Number(result[1] && result[1][0] !== '0' ? result[0] + '.' + result[1][0] : result[0]);
    }
    throw new TypeError('getAge 方法需要传入日期字符串、列如：1999-01-01')
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
