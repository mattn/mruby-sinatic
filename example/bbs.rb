#!mruby

db = SQLite3::Database.new("./bbs.db")

get "/" do
'
<script src="http://code.jquery.com/jquery-latest.js"></script>
<script>
$(function() {
  function reload() {
    $.getJSON("api", function(data) {
      var ul = $("<ul/>").appendTo($("#list").empty());
      $.each(data, function() {
        $("<li/>").text(this[1]).appendTo(ul);
      });
    });
  }
  $("#post").click(function() {
    $.post("api", {text: $("#text").val()}, function() {
      reload();
    });
  });
  reload();
});
</script>
<label for="text"/>comment:</label>
<input type="text" id="text" name="text" value="">
<input id="post" type="submit">
<div id="list"></div>
'
end

get "/api" do |r, param|
  ret = []
  db.execute('select * from bbs') do |row|
    ret += [row]
  end
  JSON.stringify ret
end

post "/api" do |r, param|
  db.execute_batch('insert into bbs(text) values(?)', param['text'])
  "true"
end

Sinatic.run :port => 5003
