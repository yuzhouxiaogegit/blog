***字符串超出省略号显示***

```Javascript

 /**
   * @description 字符串超出省略号显示
   * @param {String} txt 显示文本
   * @param {String} num 限制多少位后省略号显示，-1则是全部显示
   * @return {String} 处理后的结果
   */

  function stringEllipsis(txt, num) {
     txt = JSON.stringify(txt || '').replace(/[\'\"]/g, "");
     num = Number(num) || -1;
     if (txt.length > num && num >= 0) {
        return txt.substring(0, num) + "...";
     }
     return txt;
  }

  console.log(stringEllipsis('字符串省略号显示字符串省略号显示', 5)) // 字符串省略...
  console.log(stringEllipsis('字符串省略号显示字符串省略号显示', -1)) // 字符串省略号显示字符串省略号显示
```

***身份信息脱敏处理***
```Javascript

/**
 * 关键信息隐藏
 * @param str 字符串
 * @param frontLen 字符串前面保留位数
 * @param endLen 字符串后面保留位数
 * @returns {string}
 */

function hideCode(str, frontLen, endLen) {
   str = JSON.stringify(str || '').replace(/[\'\"]/g, "");
   let len = str.length - Number(frontLen || 0) - Number(endLen || 0);
   let xing = '';
   for (let i = 0; i < len; i++) {
      xing += '*';
   }
   if (str.length >= (frontLen + endLen)) {
      return str.substring(0, frontLen) + xing + str.substring(str.length - endLen);
   }
   return str;
}

console.log(hideCode(13015899696, 3, 4)) // 130****9696
console.log(hideCode(13015899696, -1, -1)) // 13015899696
```
