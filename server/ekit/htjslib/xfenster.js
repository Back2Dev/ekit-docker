// xFenster r17, Copyright 2004-2007 Michael Foster (Cross-Browser.com)
// Part of X, a Cross-Browser Javascript Library, Distributed under the terms of the GNU LGPL

function xFenster(clientId, iniTitle, iniUrl, iniX, iniY, iniW, iniH,
                  miniW, fenceId, conPad, conBor, cliBor,
                  enMove, enResize, enMinimize, enMaximize, enClose, enStatus, enFixed,
                  fnMove, fnResize, fnMinimize, fnMaximize, fnRestore, fnClose, fnFocus, fnLoad,
                  clsCon, clsCli, clsTB, clsTBF, clsSB, clsSBF,
                  clsRI, clsNI, clsMI, clsOI, clsCI,
                  txtResize, txtMin, txtMax, txtRestore, txtClose)
{
  var me = this;

  // Public Methods

  me.paint = function(dw, dh)
  {
    me.conW += dw;
    me.conH += dh;
    me.con.style.width = (me.conW - B2) + 'px';
    me.con.style.height = (me.conH - B2) + 'px';
    /*@cc_on
    @if (@_jscript)
      xWidth(me.tbar, me.conW - M2 - B2);
      if (!me.minimized && me.sbar) {
        xWidth(me.sbar, me.conW - M2 - B2);
        me.sbar.style.top = me.conH - me.sbar.offsetHeight - M - B2;
      }
    @end @*/
    if (!me.minimized) {
      me.client.style.top = (M + me.tbar.offsetHeight) + 'px';
      me.client.style.width = (me.conW - M2 - B2 - cB2) + 'px';
      me.client.style.height = (me.conH - me.tbar.offsetHeight - (me.sbar ? me.sbar.offsetHeight : 0) - M2 - B2 - cB2) + 'px';
    }
  };
  me.focus = function()
  {
    if (xFenster.focused != me && (!fnFocus || fnFocus(me))) {
      me.con.style.zIndex = xFenster.nextZ++;
      if (xFenster.focused) {
        xFenster.focused.tbar.className = xFenster.focused.clsTB;
        if (xFenster.focused.sbar) xFenster.focused.sbar.className = xFenster.focused.clsSB;
      }
      me.tbar.className = clsTBF;
      if (me.sbar) me.sbar.className = clsSBF;
      xFenster.focused = me;
    }
  };
  me.href = function(s)
  {
    var h = s;
    if (me.isIFrame) {
      if (me.client.contentWindow) {
        if (s) {me.client.contentWindow.location = s;}
        else h = me.client.contentWindow.location.href;
      }
      else if (typeof me.client.src == 'string') { // for Safari/Apollo/WebKit on Windows
        if (s) {me.client.src = s;}
        else h = me.client.src;
      }
    }
    return h;
  };
  me.hide = function(e)
  {
    var i, o = xFenster.instances, z = 0, hz = 0, f = null;
    if (!fnClose || fnClose(me)) {
      me.con.style.display = 'none';
      me.hidden = true;
      xStopPropagation(e);
      if (me == xFenster.focused) {
        for (i in o) { // find the next appropriate fenster to focus
          if (o.hasOwnProperty(i) && o[i] && !o[i].hidden && o[i] != me) {
            z = parseInt(o[i].con.style.zIndex);
            if (z > hz) {
              hz = z;
              f = o[i];
            }
          }
        }
        if (f) {f.focus();}
      }
    }
  };
  me.show = function()
  {
    me.con.style.display = 'block';
    me.hidden = false;
    me.focus();
  };
  me.status = function(s)
  {
    if (me.sbar) {
      if (s) {me.sbar.innerHTML = s;}
      else return me.sbar.innerHTML;
    }
  };
  me.title = function(s)
  {
    if (s) {me.tbar.innerHTML = s;}
    else return me.tbar.innerHTML;
  };
  me.destroy = function()
  {
    try {
      me.hide();
      xRemoveEventListener(window, 'unload', winUnload, false);
      xRemoveEventListener(window, 'resize', winResize, false);
      me.con.parentNode.removeChild(me.con);
      winUnload();
    }
    catch (e) {
      alert('Error in destroy:\n\n' + e);////dbg///////
    }
  };
  me.minimize = function()
  {
    if (enMinimize && !me.minimized && !me.hidden) {
      minClick();
      return true;
    }
    return false;
  };
  me.maximize = function()
  {
    if (enMaximize && !me.maximized && !me.hidden) {
      maxClick();
      return true;
    }
    return false;
  };
  me.restore = function()
  {
    var b, i, t;
    if (me.maximized) {
      b = me.mbtn;
      b.onclick = maxClick;
      i = clsMI;
      t = txtMax || '';
      me.maximized = !me.maximized;
    }
    else if (me.minimized) {
      b = me.nbtn;
      b.onclick = minClick;
      i = clsNI;
      t = txtMin || '';
      me.minimized = !me.minimized;
      me.client.style.display = 'block';
      if (me.sbar) me.sbar.style.display = 'block';
    }
    else {
      return false;
    }
    xMoveTo(me.con, rX, rY);
    b.className = i;
    b.title = t;
    if (me.rbtn) {me.rbtn.style.display = 'block';}
    me.conW = rW;
    me.conH = rH;
    me.paint(0, 0);
    if (fnRestore) fnRestore(me);
    return true;
  };

  // Private Event Listeners

  function dragStart()
  {
    var i, o = xFenster.instances;
    for (i in o) {
      if (o.hasOwnProperty(i) && o[i] && !o[i].minimized && o[i].isIFrame) {
        o[i].client.style.display = 'none';
      }
    }
  }
  function dragEnd()
  {
    var i, o = xFenster.instances;
    for (i in o) {
      if (o.hasOwnProperty(i) && o[i] && !o[i].minimized && o[i].isIFrame) {
        o[i].client.style.display = 'block';
      }
    }
  }
  function barDrag(e, mdx, mdy)
  {
    var x = me.con.offsetLeft + mdx;
    var y = me.con.offsetTop + mdy;
    if (!fnMove || fnMove(me, x, y)) {
      if (!fenceId || inFence(x, y, me.con.offsetWidth, me.con.offsetHeight)) {
        me.con.style.left = x + 'px';
        me.con.style.top = y + 'px';
      }
    }
  }
  function resDrag(e, mdx, mdy)
  {
    var w = me.con.offsetWidth + mdx;
    var h = me.con.offsetHeight + mdy;
    if (!fnResize || fnResize(me, w, h)) {
      if (!fenceId || inFence(me.con.offsetLeft, me.con.offsetTop, w, h)) {
        me.paint(mdx, mdy);
      }
    }
  }
  function maxClick()
  {
    var f, fx, fy, x = 0, y = 0, w, h, fx2, fy2;
    var sl = xScrollLeft(), st = xScrollTop();
    var cw = xClientWidth(), ch = xClientHeight();
    if (fenceId) {
      f = xGetElementById(fenceId);
      x = fx = xPageX(f);
      y = fy = xPageY(f);
      w = f.offsetWidth;
      h = f.offsetHeight;
      if (enFixed) {
        x = fx - sl;
        if (x < 0) x = 0;
        y = fy - st;
        if (y < 0) y = 0;
        
        fx2 = fx + w;
        if (fx2 >= sl + cw) fx2 = cw;
        fy2 = fy + h;
        if (fy2 >= st + ch) fy2 = ch;

        w = fx2 - x;
        h = fy2 - y;
      }
    }
    else {
      if (!enFixed) {
        x = sl;
        y = st;
      }
      w = cw;
      h = ch;
    }
    if (!fnMaximize || fnMaximize(me, w - M2 - B2, h - me.tbar.offsetHeight - (me.sbar ? me.sbar.offsetHeight : 0) - M2 - B2)) {
      me.restore();
      me.maximized = !me.maximized;
      minmax(me.mbtn, w, h, x, y);
    }
  }
  function minClick()
  {
    var r = 1, x = 2, y, h, i, o = xFenster.instances;
    if (!fnMinimize || fnMinimize(me)) {
////
      for (i in o) {
        if (o.hasOwnProperty(i) && o[i] && o[i].minimized) {
          x += o[i].con.offsetWidth + 2;
          if (x + miniW > xClientWidth()) {
            x = 2;
            ++r;
          }
        }
      }
      h = me.tbar.offsetHeight + M2 + B2;
      y = xClientHeight() - (r * (h + 2));
      if (!enFixed) y += xScrollTop();
////
      me.restore();
      me.client.style.display = 'none';
      if (me.sbar) me.sbar.style.display = 'none';
      me.minimized = !me.minimized;
      minmax(me.nbtn, miniW, h, x, y);
    }
  }
  function winResize()
  {
    if (me.maximized) {
      xResizeTo(me.con, 100, 100); // ensure fenster isn't causing scrollbars
      if (!enFixed) xMoveTo(me.con, xScrollLeft(), xScrollTop());
      me.conW = xClientWidth();
      me.conH = xClientHeight();
      me.paint(0, 0);
    }
  }
  function winUnload()
  {
    me.con.onmousedown = me.con.onclick = null;
    if (me.nbtn) me.nbtn.onclick = null;
    if (me.mbtn) me.mbtn.onclick = me.tbar.ondblclick = null;
    if (me.cbtn) me.cbtn.onclick = me.cbtn.onmousedown = null;
    xFenster.instances[clientId] = null;
    me = null;
  }

  // Private Functions

  function minmax(b, w, h, x, y)
  {
    rW = me.con.offsetWidth;
    rH = me.con.offsetHeight;
    rX = me.con.offsetLeft;
    rY = me.con.offsetTop;
    if (x != -1) {xMoveTo(me.con, x, y);}
    b.className = clsOI;
    b.title = txtRestore || '';
    b.onclick = me.restore;
    if (me.rbtn) {me.rbtn.style.display = 'none';}
    me.conW = w;
    me.conH = h;
    me.paint(0, 0);
  }
  function inFence(x, y, w, h)
  {
    var f = xGetElementById(fenceId);
    if (enFixed) {
      x += xScrollLeft();
      y += xScrollTop();
    }
    return (!(x < f.offsetLeft || x + w > f.offsetLeft + f.offsetWidth || y < f.offsetTop || y + h > f.offsetTop + f.offsetHeight));
  }

  // Constructor Code

  xFenster.instances[clientId] = this;

  // public properties
  me.con = null;  // outermost container
  me.tbar = null; // title bar
  me.sbar = null; // status bar
  me.rbtn = null; // resize icon
  me.nbtn = null; // minimize icon
  me.mbtn = null; // maximize icon
  me.cbtn = null; // close icon
  me.minimized = false;
  me.maximized = false;
  me.hidden = false;
  me.isIFrame = (typeof iniUrl == 'string');
  me.client = xGetElementById(clientId);
  me.clsSB = clsSB;
  me.clsTB = clsTB;
  me.conW = iniW;
  me.conH = iniH;

  // private properties
  var rX, rY, rW, rH; // "restore" values
  var M = conPad, B = conBor, cB = cliBor;
  var M2 = 2*M, B2 = 2*B, cB2 = 2*cB;

  // create elements
  if (!me.client) {
    me.client = document.createElement( me.isIFrame ? 'iframe' : 'div');
    me.client.id = clientId;
  }
  me.client.className += ' ' + clsCli;
  me.con = document.createElement('div');
  me.con.className = clsCon;
  if (enResize) {
    me.rbtn = document.createElement('div');
    me.rbtn.className = clsRI;
    me.rbtn.title = txtResize || '';
  }
  if (enMinimize) {
    me.nbtn = document.createElement('div');
    me.nbtn.className = clsNI;
    me.nbtn.title = txtMin || '';
  }
  if (enMaximize) {
    me.mbtn = document.createElement('div');
    me.mbtn.className = clsMI;
    me.mbtn.title = txtMax || '';
  }
  if (enClose) {
    me.cbtn = document.createElement('div');
    me.cbtn.className = clsCI;
    me.cbtn.title = txtClose || '';
  }
  me.tbar = document.createElement('div');
  me.tbar.className = clsTB;
  me.title(iniTitle);
  if (enStatus) {
    me.sbar = document.createElement('div');
    me.sbar.className = clsSB;
    me.status('&nbsp;');
  }
  // append elements
  me.con.appendChild(me.tbar);
  if (me.nbtn) me.con.appendChild(me.nbtn);
  if (me.mbtn) me.con.appendChild(me.mbtn);
  if (me.cbtn) me.con.appendChild(me.cbtn);
  me.con.appendChild(me.client);
  if (me.sbar) me.con.appendChild(me.sbar);
  if (me.rbtn) me.con.appendChild(me.rbtn);
  document.body.appendChild(me.con);
  // position and paint the fenster
  /*@cc_on
  @if (@_jscript_version <= 5.6) // IE6 or down
      enFixed = false;
    @else @*/
      if (enFixed) me.con.style.position = 'fixed';
  /*@end @*/
  me.con.style.borderWidth = conBor || 0;
  me.client.style.borderWidth = cliBor || 0;
  me.client.style.display = 'block'; // do this before paint
  me.client.style.visibility = 'visible';
  me.tbar.style.left = me.tbar.style.right = me.tbar.style.top = M + 'px';
  if (me.sbar) {me.sbar.style.left = me.sbar.style.right = me.sbar.style.bottom = M + 'px';}
  me.client.style.left = M + 'px';
  xMoveTo(me.con, iniX, iniY);
  me.paint(0, 0);
  // position icons
  var t = M + B, r = t;
  if (me.cbtn) {
    me.cbtn.style.top = t + 'px';
    me.cbtn.style.right = r + 'px';
    r += me.cbtn.offsetWidth + 2;
  }
  if (me.mbtn) {
    me.mbtn.style.top = t + 'px';
    me.mbtn.style.right = r + 'px';
    r += me.mbtn.offsetWidth + 2;
  }
  if (me.nbtn) {
    me.nbtn.style.top = t + 'px';
    me.nbtn.style.right = r + 'px';
  }
  if (me.rbtn) {
    me.rbtn.style.right = me.rbtn.style.bottom = t + 'px';
  }
  // register event listeners
  if (me.isIFrame) {
    me.href(iniUrl);
    if (fnLoad) {xAddEventListener(me.client, 'load', function(){fnLoad(me);}, false);}
    me.client.name = clientId;
  }
  if (enMove) xEnableDrag(me.tbar, dragStart, barDrag, dragEnd);
  if (enResize) xEnableDrag(me.rbtn, dragStart, resDrag, dragEnd);
  me.con.onmousedown = me.focus;
  if (enMinimize) me.nbtn.onclick = minClick;
  if (enMaximize) me.mbtn.onclick = me.tbar.ondblclick = maxClick;
  if (enClose) {
    me.cbtn.onclick = me.hide;
    me.cbtn.onmousedown = xStopPropagation;
  }
  xAddEventListener(window, 'unload', winUnload, false);
  xAddEventListener(window, 'resize', winResize, false);
  // show the fenster
  me.con.style.visibility = 'visible';
  me.focus();

} // end xFenster object prototype

// xFenster static properties
xFenster.nextZ = 100;
xFenster.focused = null;
xFenster.instances = {};

