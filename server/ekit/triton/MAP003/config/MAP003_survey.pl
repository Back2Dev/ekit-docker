bless({
  _SID           => "MAP003",
  _TritonRoot    => "/home/vhosts/pwidev/triton",
  _config_subdir => "config",
  _data_subdir   => "web",
  _doc_root      => undef,
  _doc_subdir    => "doc",
  _final_subdir  => "final",
  _html_subdir   => "html",
  _masks         => {},
  _options       => {
                      block_size       => 5,
                      custom_footer    => "<center><img src=\"/themes/ekit/ekit.daa.png\" alt=\"Discipline, Accountability, Achievement\" ></center>",
                      focus_off        => 1,
                      mailto           => "ctwebb\@mapconsulting.com",
                      no_copy          => 1,
                      no_progress_bar  => 1,
                      one_at_a_time    => 0,
                      optional_written => 0,
                      qbanner          => "<table border=0 cellpadding=0 cellspacing=0 class=\"bannertable\"><tr><TD class=\"bannerlogo\">&nbsp;<TD width=\"50px\" >&nbsp;<tr><TD class=\"bluebar\"> &nbsp;&nbsp; Time Allocation<TH class=\"bluebarq\">Q3</table>",
                      qscale           => "<P><%q_label%>",
                      survey_name      => "Time Allocation",
                      thankyou_url     => "thanks.htm",
                      theme            => "ekit",
                      window_title     => "Q3 - Time Allocation",
                    },
  _questions     => [
                      bless({
                        _a_varnames => [],
                        _attributes => [],
                        _code       => [
                                         "duedate=duedate",
                                         "id=id",
                                         "token=token",
                                         "login_page=login_page",
                                         "warning=warning",
                                         "ws_details=ws_details",
                                         "qbanner=qbanner",
                                         "qscale=qscale",
                                       ],
                        _dataInfo   => [],
                        _label      => "AA",
                        _opt        => { instr => "", scale => 0 },
                        _prompt     => "",
                        _qnum       => 1,
                        _qtype      => 20,
                        _scores     => [],
                        _setvalues  => [],
                        _skips      => [],
                        _vars       => [],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames    => [],
                        _attributes    => [],
                        _dataInfo      => [
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_1",
                                              type => "TEXT",
                                              var => "spentq1_1",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_1",
                                              type => "TEXT",
                                              var => "opensq1_1",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_1",
                                              type => "TEXT",
                                              var => "shouldq1_1",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_2",
                                              type => "TEXT",
                                              var => "spentq1_2",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_2",
                                              type => "TEXT",
                                              var => "opensq1_2",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_2",
                                              type => "TEXT",
                                              var => "shouldq1_2",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_3",
                                              type => "TEXT",
                                              var => "spentq1_3",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_3",
                                              type => "TEXT",
                                              var => "opensq1_3",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_3",
                                              type => "TEXT",
                                              var => "shouldq1_3",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_4",
                                              type => "TEXT",
                                              var => "spentq1_4",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_4",
                                              type => "TEXT",
                                              var => "opensq1_4",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_4",
                                              type => "TEXT",
                                              var => "shouldq1_4",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_5",
                                              type => "TEXT",
                                              var => "spentq1_5",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_5",
                                              type => "TEXT",
                                              var => "opensq1_5",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_5",
                                              type => "TEXT",
                                              var => "shouldq1_5",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spentq1_6",
                                              type => "TEXT",
                                              var => "spentq1_6",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 30,
                                              "pos" => 0,
                                              rkey => "ext_opensq1_6",
                                              type => "TEXT",
                                              var => "opensq1_6",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldq1_6",
                                              type => "TEXT",
                                              var => "shouldq1_6",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_spenttot",
                                              type => "TEXT",
                                              var => "spenttot",
                                              var_label => "Main question",
                                            },
                                            {
                                              "length" => 3,
                                              "pos" => 0,
                                              rkey => "ext_shouldtot",
                                              type => "TEXT",
                                              var => "shouldtot",
                                              var_label => "Main question",
                                            },
                                            {
                                              "pos" => 0,
                                              rkey => "ext_q_labs",
                                              var => "q_labs",
                                              var_label => "Main question",
                                            },
                                            {
                                              "pos" => 0,
                                              rkey => "ext_session",
                                              type => "hidden",
                                              var => "session",
                                              var_label => "Main question",
                                            },
                                          ],
                        _external_info => {
                                            names    => [
                                                          "spentq1_1",
                                                          "opensq1_1",
                                                          "shouldq1_1",
                                                          "spentq1_2",
                                                          "opensq1_2",
                                                          "shouldq1_2",
                                                          "spentq1_3",
                                                          "opensq1_3",
                                                          "shouldq1_3",
                                                          "spentq1_4",
                                                          "opensq1_4",
                                                          "shouldq1_4",
                                                          "spentq1_5",
                                                          "opensq1_5",
                                                          "shouldq1_5",
                                                          "spentq1_6",
                                                          "opensq1_6",
                                                          "shouldq1_6",
                                                          "spenttot",
                                                          "shouldtot",
                                                          "q_labs",
                                                          "session",
                                                        ],
                                            options  => {
                                                          opensq1_1  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_1",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 2,
                                                                          type     => "TEXT",
                                                                        },
                                                          opensq1_2  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_2",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 5,
                                                                          type     => "TEXT",
                                                                        },
                                                          opensq1_3  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_3",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 8,
                                                                          type     => "TEXT",
                                                                        },
                                                          opensq1_4  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_4",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 11,
                                                                          type     => "TEXT",
                                                                        },
                                                          opensq1_5  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_5",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 14,
                                                                          type     => "TEXT",
                                                                        },
                                                          opensq1_6  => {
                                                                          class    => "input",
                                                                          name     => "opensq1_6",
                                                                          onchange => "yuk(this)",
                                                                          size     => 30,
                                                                          tabindex => 17,
                                                                          type     => "TEXT",
                                                                        },
                                                          q_labs     => {},
                                                          session    => { name => "session", type => "hidden", value => "" },
                                                          shouldq1_1 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_1",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 3,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldq1_2 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_2",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 6,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldq1_3 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_3",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 9,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldq1_4 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_4",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 12,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldq1_5 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_5",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 15,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldq1_6 => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldq1_6",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 18,
                                                                          type      => "TEXT",
                                                                        },
                                                          shouldtot  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "shouldtot",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 20,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_1  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_1",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 1,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_2  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_2",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 4,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_3  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_3",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 7,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_4  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_4",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 10,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_5  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_5",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 13,
                                                                          type      => "TEXT",
                                                                        },
                                                          spentq1_6  => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spentq1_6",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 16,
                                                                          type      => "TEXT",
                                                                        },
                                                          spenttot   => {
                                                                          class     => "input",
                                                                          maxlength => 3,
                                                                          name      => "spenttot",
                                                                          onchange  => "yuk(this)",
                                                                          size      => 6,
                                                                          tabindex  => 19,
                                                                          type      => "TEXT",
                                                                        },
                                                        },
                                            "values" => {},
                                          },
                        _label         => 1,
                        _opt           => { external => "timealloc.htm", instr => "", scale => 0 },
                        _prompt        => "Main question",
                        _qnum          => 2,
                        _qtype         => 7,
                        _scores        => [],
                        _setvalues     => [],
                        _skips         => [],
                        _vars          => [],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames => [],
                        _attributes => [],
                        _code       => [
                                         "my \$dcount = &count_data;",
                                         "&debug(\"Datacount = \$dcount\");",
                                         "if (\$dcount>0) {\$q_no = goto_qlab(\"LAST\") - 1;}",
                                         "if (\$dcount==0) {&db_conn;&db_set_status(\$survey_id,\$resp{id},\$resp{token},0,0)};",
                                       ],
                        _dataInfo   => [],
                        _label      => "CHECK",
                        _opt        => { instr => "", scale => 0 },
                        _prompt     => "Check if we have enough data to allow submission of form",
                        _qnum       => 3,
                        _qtype      => 27,
                        _scores     => [],
                        _setvalues  => [],
                        _skips      => [],
                        _vars       => [],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames    => [],
                        _attributes    => [],
                        _dataInfo      => [
                                            {
                                              "pos" => 0,
                                              rkey => "ext_BACK2",
                                              type => "hidden",
                                              var => "BACK2",
                                              var_label => "See external page \"nodata.htm\"",
                                            },
                                          ],
                        _external_info => {
                                            names    => [undef, "BACK2"],
                                            options  => {
                                                          "" => {
                                                                alt => "HOME",
                                                                onclick => "document.location='/cgi-mr/pwikit_login.pl?id=<%id%>&password=<%token%>'",
                                                                tabindex => -1,
                                                                type => "BUTTON",
                                                                value => " HOME ",
                                                              },
                                                          BACK2 => { name => "BACK2", type => "hidden" },
                                                        },
                                            "values" => { "" => [" HOME ", " GO BACK "] },
                                          },
                        _label         => "NODATA",
                        _opt           => { external => "nodata.htm", instr => "", scale => 0 },
                        _prompt        => "See external page \"nodata.htm\"",
                        _qnum          => 4,
                        _qtype         => 7,
                        _scores        => [],
                        _setvalues     => [],
                        _skips         => [],
                        _vars          => [],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames    => [],
                        _attributes    => [],
                        _dataInfo      => [
                                            {
                                              "pos" => 0,
                                              rkey => "ext_finish",
                                              type => "hidden",
                                              var => "finish",
                                              var_label => "This is implemented as an external",
                                            },
                                            {
                                              "pos" => 0,
                                              rkey => "ext_q_labs",
                                              var => "q_labs",
                                              var_label => "This is implemented as an external",
                                            },
                                            {
                                              "pos" => 0,
                                              rkey => "ext_BACK2",
                                              type => "hidden",
                                              var => "BACK2",
                                              var_label => "This is implemented as an external",
                                            },
                                          ],
                        _external_info => {
                                            names    => ["finish", "q_labs", undef, "BACK2"],
                                            options  => {
                                                          "" => {
                                                                onclick => "document.q.finish.value='';",
                                                                type    => "SUBMIT",
                                                                value   => " SUBMIT ",
                                                              },
                                                          BACK2 => { name => "BACK2", type => "hidden" },
                                                          finish => { name => "finish", type => "hidden" },
                                                          q_labs => {},
                                                        },
                                            "values" => { "" => [" SUBMIT ", "NOT YET", " GO BACK "] },
                                          },
                        _label         => "LAST",
                        _opt           => { external => "last.htm", instr => "", scale => 0 },
                        _prompt        => "This is implemented as an external",
                        _qnum          => 5,
                        _qtype         => 7,
                        _scores        => [],
                        _setvalues     => [],
                        _skips         => [],
                        _vars          => [],
                      }, "TPerl::Survey::Question"),
                    ],
}, "TPerl::Survey")