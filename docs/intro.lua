return [[
<h1>CoG — Code of Gaming</h1>
<p>CoG supplies game systems for Lua: resources, progression, items and equipment,
rarity and affixes, targeting and statuses, cards, weighted navigation, Tiled
maps and moddable content. Build your own gameplay classes on its shared object
foundations.</p>
<h3>Start with LuaEx, then CoG</h3>
<pre><code class="language-lua">local initLuaEx = require(&quot;LuaEx.load&quot;);
initLuaEx();

local initCoG = require(&quot;cog.load&quot;);
local CoG = initCoG();
</code></pre>
<p>Place the LuaEx and cog folders on the module search path. CoG requires
<code>LUAEX_INIT == true</code>. Read the completed, locked project settings through
<code>CoG.config</code>. Optional config-parent depth and basename arguments select your
project&#39;s override file.</p>
<p>Browse the <a href="#CoG">CoG API</a> in the navigation tree for component contracts,
constructors, methods and examples.</p>


]];
