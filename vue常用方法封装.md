***动态初始化data方法***
```javascript
<template>
  <div></div>
</template>

<script>
export default {
  data() {
    return {
      test: {
        test2: {
          data2: {
            value: [1111, 123145]
          },
          test3: {
            value: [1111, 123145]
          }
        }
      }
    };
  },
  mounted() {
    this.test.test2.data2.value = {
      name: "李一"
    };
    this.test.test2.test3.value = {
      name: "李二"
    };

    this.vueInitData(this, "test.test2.data2"); // 局部初始化值
    console.log(this.test.test2.data2.value); // 结果为：默认值

    this.vueInitData(this, "test"); // 初始化整个对象
    console.log(this.test); // 结果为：test: { test2: {data2: { value: [1111, 123145]},test3: {value: [1111, 123145]} }}
  },
  methods: {
    vueInitData(that, key = "") {
      let runStr = `Object.assign(that.$data,that.$options.data());`;
      if (typeof key == "string" && key) {
        runStr = `that.${key} = that.$options.data().${key};`;
      }
      new Function("that", `${runStr};`)(that);
    }
  }
};
</script>

<style lang="scss" scoped>
</style>

```
