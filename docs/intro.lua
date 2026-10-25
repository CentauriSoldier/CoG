return [[
<h1>CoG — Code of Gaming</h1>
<h2>Version 2.1</h2>
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

<details>
<summary>View changelog</summary>
<h1>CoG changelog</h1>
<h2>v2.1</h2>
<h3>Added</h3>
<ul>
<li>Standalone <code>cog.load</code> initializer with separate loading after LuaEx.</li>
<li>Versioned documentation introduction and generated HTML API reference for GitHub Pages.</li>
<li>A repository overview with gameplay examples and a dark pixel-art banner.</li>
</ul>
<h3>Changed</h3>
<ul>
<li>Configuration is assembled and locked before the CoG class is declared, then exposed as public static <code>CoG.config</code>.</li>
<li><code>require(&quot;cog.config&quot;)</code> returns the same read-only configuration table.</li>
<li>CoG module imports use the standalone <code>cog.*</code> namespace.</li>
<li>Initialization requires <code>LUAEX_INIT == true</code>; LuaEx remains a dependency.</li>
</ul>
<h3>Fixed</h3>
<ul>
<li>Internal AStar documentation links now use <code>CoG.*</code> FQXNs without the former LuaEx ownership prefix.</li>
</ul>

</details>
]];
