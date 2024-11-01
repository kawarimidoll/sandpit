-module(functions).
%% replace with -export() later
-compile(export_all).

head([H | _]) -> H.
second([_, X | _]) -> X.

same(X, X) -> true;
same(_, _) -> false.

right_age(X) when X > 16, X < 100 ->
    true;
right_age(_) ->
    false.
