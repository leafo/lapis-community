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
    describe "convert_array", ->
      local convert_array

      before_each ->
        import convert_array from require "community.helpers.shapes"

      it "converts table", ->
        input = {
          "1": "hello"
          "2": "world"
          "3": "zone"
          "999": "zone"
        }

        assert.same {
          "hello", "world", "zone"
        }, convert_array\transform input

      it "empty table", ->
        assert.same {}, convert_array\transform {}

      it "table with no array", ->
        input = {
          hello: "world"
          thing: { "one", "two" }
        }

        assert.same {}, convert_array\transform input

      it "converts existing array", ->
        assert.same {
          "one", "two"
        }, convert_array\transform {"one", "two"}

        assert.same {
          {"first"}, {"second"}
        }, convert_array\transform {
          {"first"}, {"second"}
          picker: "true"
        }


    describe "page_number", ->
      local page_number

      before_each ->
        import page_number from require "community.helpers.shapes"

      it "passes valid value", ->
        assert.same 1, page_number\transform "1"
        assert.same 200, page_number\transform "200"
        assert.same nil, (page_number\transform " 5 ")

        assert.same 1, page_number\transform 1
        assert.same 50, page_number\transform 50
        assert.same nil, (page_number\transform -20)
        assert.same 3, page_number\transform 3.5

        assert.same 1, page_number\transform nil
        assert.same 1, page_number\transform ""

      it "fails invalid string", ->
        assert.same {nil, "expected empty, or page number"}, {page_number\transform "hello"}
        assert.same {nil, "expected empty, or page number"}, {page_number\transform "nil"}
        assert.same {nil, "expected empty, or page number"}, {page_number\transform " 5 f"}
        assert.same {nil, "expected empty, or page number"}, {page_number\transform "-5"}
        assert.same {nil, "expected empty, or page number"}, {page_number\transform "5.3"}

    describe "utc_datetime", ->
      local utc_datetime

      before_each ->
        import utc_datetime from require "community.helpers.shapes"

      it "converts to utc", ->
        assert.same "2026-10-05 18:00:00", utc_datetime\transform "2026-10-05T18:00:00Z"
        assert.same "2026-10-05 18:00:00", utc_datetime\transform "2026-10-05T18:00:00.123Z"
        assert.same "2026-10-05 18:00:00", utc_datetime\transform "2026-10-05T20:00:00+02:00"
        assert.same "2026-10-05 18:00:00", utc_datetime\transform "2026-10-05T13:30:00-04:30"
        assert.same "2026-10-06 01:00:00", utc_datetime\transform "2026-10-05T23:00:00-02:00"
        assert.same "2026-10-05 04:00:00", utc_datetime\transform "2026-10-05T18:00:00+14:00"

      it "fails invalid input", ->
        for input in *{
          "2026-10-05T18:00:00"
          "2026-10-05 18:00:00Z"
          "2026-10-05"
          "2026-13-01T00:00:00Z"
          "2026-02-30T00:00:00Z"
          "2026-10-05T25:00:00Z"
          "2026-10-05T18:00:0012Z"
          "2026-10-05T18:00:00+2:00"
          "2026-10-05T18:00:00+99:99"
          "2026-10-05T18:00:00+02:60"
          "2026-10-05T18:00:00Zjunk"
          "1700000000"
          ""
          123
        }
          assert.same {nil, "expected ISO 8601 date with timezone"},
            {utc_datetime\transform input}, "input: #{input}"

