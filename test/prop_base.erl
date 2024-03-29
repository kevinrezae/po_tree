-module(prop_base).
-include_lib("proper/include/proper.hrl").
-define(MIN, 1).
-define(MAX, 1000000).
%%%%%%%%%%%%%%%%%%
%%% Properties %%%
%%%%%%%%%%%%%%%%%%
prop_test() ->
    ?FORALL(List, insert_remove_list_gen(),
        begin
            check_range(List)
        end).

%%%%%%%%%%%%%%%
%%% Helpers %%%
%%%%%%%%%%%%%%%
check_range(List) ->
    po_tree_server:init_tree(),
    po_tree_server:clean_store(),
    PreparedList = prepare_list(List),
    construct_index(PreparedList, 1, []).

construct_index([], _Ver, _InsertedList) ->
    true;

construct_index([{InsertList, RemoveList} | T], Ver, InsertedList) ->
    NewInsertedList = construct_list(InsertList, RemoveList, InsertedList),
    insert(InsertList, Ver),
    remove(RemoveList, Ver),
    IndexRes = po_tree_server:get_range(?MIN,?MAX,true,true,Ver),
    case compare_lists2( ordsets:to_list(ordsets:from_list(NewInsertedList)), IndexRes) of
        true ->
            construct_index(T, Ver+1, NewInsertedList);
        false ->
            false
    end.

insert([], _Ver) ->
    ok;
insert([{RowId, Val} | T], Ver) ->
    po_tree_server:insert({RowId, Val, Ver}),
    insert(T, Ver).

remove([], _Ver) ->
    ok;
remove([{RowId, Val} | T], Ver) ->
    po_tree_server:remove(RowId, Val, Ver),
    remove(T, Ver).


construct_list([], [], List) ->
   List;
construct_list([], [{RowId, Val} | T], List) ->
    NewList = remove_from_list({Val, RowId}, List),
    construct_list([], T, NewList);
construct_list([{RowId, Val} | T], RemoveList, List) ->
    UniqueList = remove_duplicate_rowId(List, RowId),
    NewList = lists:sort([{Val, RowId}] ++ UniqueList),
    construct_list(T, RemoveList, NewList).

remove_from_list({_Val, _RowId}, []) ->
    [];
remove_from_list({Val, RowId}, [{ListVal, ListRow} | T]) when Val == ListVal, RowId == ListRow->
    remove_from_list({Val, RowId}, T);
remove_from_list({Val, RowId}, [{ListVal, ListRow} | T])->
    [{ListVal, ListRow}] ++ remove_from_list({Val, RowId}, T).


compare_lists2([], []) ->
    true;
compare_lists2([], [{_Val, _Rows} | _T]) ->
    true;
compare_lists2([_Val | _T], []) ->
    false;
compare_lists2([{Val, RowId} | ListT], RangeRes) ->
    case contains({Val, RowId}, RangeRes) of
        true ->
            compare_lists2(ListT, RangeRes);
        false -> false
    end.

contains({_Val, _RowId}, []) ->
    false ;
contains({Val, RowId}, [{IndexVal, Rows} | _IndexT]) when Val == IndexVal ->
    lists:member(RowId, Rows);
contains({Val, RowId}, [{_IndexVal, _Rows} | IndexT]) ->
    contains({Val, RowId}, IndexT).



%%%%%%%%%%%%%%%%%%
%%% Generators %%%
%%%%%%%%%%%%%%%%%%
insert_remove_list_gen() ->
    list({list({range(?MIN,?MAX), range(?MIN,?MAX)}), list({range(?MIN,?MAX), range(?MIN,?MAX)})}).

prepare_list([]) ->
    [];
prepare_list([{Insert, Remove} | T]) ->
    UniqueInsert = remove_duplicate_keys(Insert, []),
    [{UniqueInsert, Remove}] ++ prepare_list(T).

remove_duplicate_keys([], _Acc) ->
    [];
remove_duplicate_keys([{RowId, Val} | T], Acc) ->
    case lists:member(RowId, Acc) of
        true ->
            remove_duplicate_keys(T, Acc);
        false ->
            [{RowId, Val}] ++ remove_duplicate_keys(T, [RowId]++Acc)
    end.


remove_duplicate_rowId([], _Row) ->
    [];
remove_duplicate_rowId([{Val, RowId} | T], Row) ->
    case RowId =:= Row of
        true ->
            remove_duplicate_rowId(T, Row);
        false ->
            [{Val, RowId}] ++ remove_duplicate_rowId(T, Row)
    end.
