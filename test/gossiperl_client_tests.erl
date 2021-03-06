%% Copyright (c) 2014 Radoslaw Gruchalski <radek@gruchalski.com>
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

-module(gossiperl_client_tests).
-include_lib("eunit/include/eunit.hrl").

-define(OVERLAY_NAME, <<"gossiper_overlay_remote">>).
-define(CLIENT_PORT, 54321).
-define(OVERLAY_PORT, 6666).
-define(CLIENT_NAME, <<"client-test">>).
-define(CLIENT_SECRET, <<"client-test">>).
-define(SYMMETRIC_KEY, <<"v3JElaRswYgxOt4b">>).

-define(SUBSCRIPTIONS, [member_in, member_out]).

gossiperl_client_test_() ->
  {setup, fun start/0, fun stop/1, [
    fun connect_to/0,
    fun subscribe_to/0,
    fun unsubscribe_from/0,
    fun disconnect_from/0,
    fun custom_serialization/0 ] }.

start() ->
  Applications = [ asn1, crypto, public_key, erlsha2, jsx, thrift,
                   quickrand, uuid, syntax_tools, compiler,
                   goldrush, lager, gossiperl_client ],
  [ begin
      Result = application:start(App),
      error_logger:info_msg("Starting application ~p: ~p", [ App, Result ] )
    end || App <- Applications ],
  ok.

stop(_State) ->
  noreply.

connect_to() ->
  ConnectReponse = gossiperl_client_sup:connect([
      { overlay_name, ?OVERLAY_NAME },
      { overlay_port, ?OVERLAY_PORT },
      { client_name, ?CLIENT_NAME },
      { client_secret, ?CLIENT_SECRET },
      { client_port, ?CLIENT_PORT },
      { symmetric_key, ?SYMMETRIC_KEY } ]),
  ?assertMatch({ok, _}, ConnectReponse),
  timer:sleep(3000),
  ?assertMatch(operational, gossiperl_client_sup:check_state(?OVERLAY_NAME)),
  ok.

subscribe_to() ->
  SubscribeReponse = gossiperl_client_sup:subscribe(
    ?OVERLAY_NAME,
    ?SUBSCRIPTIONS ),
  ?assertMatch({ok, ?SUBSCRIPTIONS}, SubscribeReponse),
  timer:sleep(1000),
  ?assertMatch(?SUBSCRIPTIONS, gossiperl_client_sup:subscriptions(?OVERLAY_NAME)),
  ok.

unsubscribe_from() ->
  UnsubscribeReponse = gossiperl_client_sup:unsubscribe(
    ?OVERLAY_NAME,
    ?SUBSCRIPTIONS ),
  ?assertMatch({ok, ?SUBSCRIPTIONS}, UnsubscribeReponse),
  timer:sleep(1000),
  ?assertMatch([], gossiperl_client_sup:subscriptions(?OVERLAY_NAME)),
  ok.

disconnect_from() ->
  DisconnectReponse = gossiperl_client_sup:disconnect( ?OVERLAY_NAME ),
  ?assertMatch(ok, DisconnectReponse),
  timer:sleep(3000),
  ok.

custom_serialization() ->
  DigestType = someCustomDigest,
  DigestData = [
    { some_data, <<"some data to send">>, string, 1 },
    { some_port_number, 1234, i32, 2 } ],
  DigestId = <<"some-digest-id">>,
  DigestInfo = [
    { 1, string },
    { 2, i32 } ],
  
  % serialize:
  SerializaeResult = gen_server:call( gossiperl_client_serialization, { serialize, DigestType, DigestData, DigestId } ),
  ?assertMatch( { ok, DigestType, _ }, SerializaeResult ),
  { ok, DigestType, BinaryEnvelope } = SerializaeResult,
  ?assert( is_binary( BinaryEnvelope ) =:= true ),

  %deserialize:
  DeserializedResult = gen_server:call( gossiperl_client_serialization, { deserialize, DigestType, BinaryEnvelope, DigestInfo } ),
  ?assertMatch( { ok, DigestType, _ }, DeserializedResult ),
  { ok, DigestType, CustomDigest } = DeserializedResult,
  ?assertMatch( { <<"some data to send">>, 1234 }, CustomDigest ),
  ok.
