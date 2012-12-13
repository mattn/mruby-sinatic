#!mruby

get "/" do
'
<script src="http://code.jquery.com/jquery-latest.js"></script>
<script src="/foo.js"></script>
<div id="foo"></div>
<img src="/logo.png"><br />
<form action="/add" method="post">
<label for="name"/>お名前</label>
<input type="text" id="name" name="name" value="">
<input type="submit">
</form>
'
end

post "/add" do |r, param|
"
<meta http-equiv=refresh content='2; URL=/'>
通報しますた「#{param['name']}」
"
end

Sinatic.run
