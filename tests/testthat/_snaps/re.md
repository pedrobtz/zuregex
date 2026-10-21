# re objects format, print and subset

    Code
      print(re)
    Output
      <re[3]>
      [1] /a+/i
      [2] <NA>
      [3] /b/i

---

    Code
      print(re_compile(character()))
    Output
      <re[0]>

---

    Code
      print(re_compile("\\d+\\."))
    Output
      <re[1]>
      [1] /\d+\./

