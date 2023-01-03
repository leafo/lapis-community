describe "community.helpers", ->

  describe "models", ->
    import memoize1 from require "community.helpers.models"

    it "memoizes method", ->
      class M
        calls: 0

        new: (@initial) =>

        value: memoize1 (t) =>
          @calls += 1
          @initial + t.amount

      a = M 2
      b = M 3

      i1 = amount: 2
      i2 = amount: 3

      assert.same 4, a\value i1
      assert.same 5, a\value i2
      assert.same 4, a\value i1

      assert.same 2, a.calls

      assert.same 5, b\value i1
      assert.same 6, b\value i2
      assert.same 5, b\value i1

      assert.same 2, b.calls


  describe "shapes", ->
    describe "page_number", ->
      local page_number

      before_each ->
        import page_number from require "community.helpers.shapes"

      it "passes valid value", ->
        assert.same 1, page_number\transform "1"
        assert.same 200, page_number\transform "200"
        assert.same 5, page_number\transform " 5 "

        assert.same 1, page_number\transform 1
        assert.same 50, page_number\transform 50
        assert.same 1, page_number\transform -20
        assert.same 3, page_number\transform 3.5

        assert.same 1, page_number\transform nil
        assert.same 1, page_number\transform ""

      it "fails invalid string", ->
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "hello"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "nil"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform " 5 f"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "-5"}
        assert.same {nil, "expected empty, or an integer"}, {page_number\transform "5.3"}

