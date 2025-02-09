bless({
  _SID           => "MAP006",
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
                      expid            => "em4853af-0",
                      focus_off        => 1,
                      mailto           => "ctwebb\@mapconsulting.com",
                      no_copy          => 1,
                      no_progress_bar  => 1,
                      one_at_a_time    => 0,
                      optional_written => 0,
                      qbanner          => "<table border=0 cellpadding=0 cellspacing=0 class=\"bannertable\"><tr><TD class=\"bannerlogo\">&nbsp;<TD width=\"50px\" >&nbsp;<tr><TD class=\"bluebar\"> &nbsp;&nbsp; Style Insights&reg; (DISC)<TH class=\"bluebarq\">Q6</table>",
                      qscale           => "<P><%q_label%>",
                      survey_name      => "Style Insights&reg; (DISC)",
                      thankyou_url     => "thanks.htm",
                      theme            => "ekitdisc",
                      window_title     => "Q6 - Style Insights&reg; (DISC)",
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
                        _a_varnames => [],
                        _attributes => ["BOGUS"],
                        _dataInfo   => [],
                        _label      => 1,
                        _opt        => { instr => "", scale => 0 },
                        _prompt     => "<%qbanner%> <table width=\"600px\" border=\"0\"><TR><TD><P><FONT SIZE=\"+1\"> The DISC test takes about 15-20 minutes to complete. You cannot come back and complete the test once you start it. Please be sure you can allocate 15-20 minutes PRIOR to proceeding. If you cannot allocate 15-20 minutes at this time, please <A HREF=\"\$\$login_page\">click here </a> to return to the list of forms.</FONT> <P>To take the test, click the \"Take Test\" button, below.<P><font size=\"-2\">The DISC test is Copyright (c) 1999, 2012 - Target Training International, Ltd</FONT></table>",
                        _qnum       => 2,
                        _qtype      => 7,
                        _scores     => [0],
                        _setvalues  => [undef],
                        _skips      => [undef],
                        _vars       => [undef],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames => [],
                        _attributes => [],
                        _code       => [
                                         "use Time::Local;",
                                         "\$resp{status} = 4;",
                                         "&update_token_status(4);",
                                       ],
                        _dataInfo   => [],
                        _label      => "1A",
                        _opt        => { instr => "", scale => 0 },
                        _prompt     => "",
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
                        _dataInfo      => [],
                        _external_info => { "values" => {} },
                        _label         => "2B",
                        _opt           => { external => "disc3.htm", instr => "", scale => 0 },
                        _prompt        => "External page which takes you to DISC test - if workshop is AFTER May 1 2004",
                        _qnum          => 4,
                        _qtype         => 7,
                        _scores        => [],
                        _setvalues     => [],
                        _skips         => [],
                        _vars          => [],
                      }, "TPerl::Survey::Question"),
                      bless({
                        _a_varnames => [],
                        _attributes => [],
                        _dataInfo   => [],
                        _label      => "END",
                        _opt        => { instr => "", scale => 0 },
                        _prompt     => "End",
                        _qnum       => 5,
                        _qtype      => 8,
                        _scores     => [],
                        _setvalues  => [],
                        _skips      => [],
                        _vars       => [],
                      }, "TPerl::Survey::Question"),
                    ],
}, "TPerl::Survey")