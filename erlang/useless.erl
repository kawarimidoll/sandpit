-module(useless).
% https://www.ymotongpoo.com/works/lyse-ja/ja/04_modules.html

-export([add/2, hello/0]).

add(A,B) ->
  A + B.

%% Shows greetings.
%% io:format/1 is the standard function used to output text.
hello() ->
  io:format("Hello, world!~n").
