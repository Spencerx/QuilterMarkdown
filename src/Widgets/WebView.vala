/*
* Copyright (c) 2017-2021 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/
namespace Quilter {
    public class Widgets.Preview : WebKit.WebView {
        private static Preview? instance = null;
        public Widgets.EditView buf;
        public string html;
        public double scroll_value {
            set {
                evaluate_javascript.begin ("""
                    var b = document.body,
                    e = document.documentElement;
                    var height = Math.max( b.scrollHeight,
                                           b.offsetHeight,
                                           e.clientHeight,
                                           e.scrollHeight,
                                           e.offsetHeight
                                 );
                    e.scrollTop = (%.13f * e.offsetHeight);
                    e.scrollTop;
                """.printf (value), 0, null, null);
            }
        }

        public static Preview get_instance () {
            if (instance == null) {
                instance = new Widgets.Preview (Application.win, Application.win.edit_view_content);
            }

            return instance;
        }

        public Preview (MainWindow window, Widgets.EditView buf) {
            Object (user_content_manager: new WebKit.UserContentManager ());
            this.buf = buf;
            var webkit_settings = get_settings ();
            webkit_settings.enable_page_cache = false;
            webkit_settings.javascript_can_open_windows_automatically = false;

            this.scroll_value = -1;

            update_html_view ();
            connect_signals ();
        }

        protected override bool context_menu (
            WebKit.ContextMenu context_menu,
            WebKit.HitTestResult hit_test_result
        ) {
            return true;
        }

        private string set_stylesheet () {
            if (Quilter.Application.gsettings.get_string ("visual-mode") == "dark") {
                string dark = Styles.quilterdark.css;
                return dark;
            } else if (Quilter.Application.gsettings.get_string ("visual-mode") == "sepia") {
                string sepia = Styles.quiltersepia.css;
                return sepia;
            } else if (Quilter.Application.gsettings.get_string ("visual-mode") == "light") {
                string normal = Styles.quilter.css;
                return normal;
            }
            return "";
        }

        private string set_font_stylesheet () {
            if (Quilter.Application.gsettings.get_enum ("preview-font") == 0) {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/font/serif.css";
            } else if (Quilter.Application.gsettings.get_enum ("preview-font") == 1) {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/font/sans.css";
            } else if (Quilter.Application.gsettings.get_enum ("preview-font") == 2) {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/font/mono.css";
            }

            return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/font/serif.css";
        }

        private string set_highlight_stylesheet () {
            if (Quilter.Application.gsettings.get_string ("visual-mode") == "dark") {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/highlight.js/styles/dark.min.css";
            } else if (Quilter.Application.gsettings.get_string ("visual-mode") == "sepia") {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/highlight.js/styles/sepia.min.css";
            } else if (Quilter.Application.gsettings.get_string ("visual-mode") == "light") {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/highlight.js/styles/default.min.css";
            } else {
                return "";
            }
        }


        private string set_highlight () {
            if (Quilter.Application.gsettings.get_boolean ("highlight")) {
                string render = Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/highlight.js/lib/highlight.min.js";
                string hl = """
                    <link rel="stylesheet" href="%s">
                    <script defer src="%s" onload="hljs.initHighlightingOnLoad();"></script>
                """.printf (set_highlight_stylesheet (), render);
                return hl;
            } else {
                return "";
            }
        }

        private string set_center_headers () {
            if (Quilter.Application.gsettings.get_boolean ("center-headers")) {
                return Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/center_headers/cheaders.css";
            } else {
                return "";
            }
        }

        private string set_latex () {
            if (Quilter.Application.gsettings.get_boolean ("latex")) {
                string katex_main = Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/katex/katex.css";
                string katex_js = Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/katex/katex.js";
                string render = Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/katex/render.js";
                string latex = """
                    <link rel="stylesheet" href="%s">
                    <script defer src="%s"></script>
                    <script defer src="%s" onload="renderMathInElement(document.body);"></script>
                """.printf (katex_main, katex_js, render);
                return latex;
            } else {
                return "";
            }
        }

        private string set_mermaid () {
            if (Quilter.Application.gsettings.get_boolean ("mermaid")) {
                string render = Environment.get_system_data_dirs ()[0] + "/io.github.lainsce.Quilter/mermaid/mermaid.js";
                string mermaid = """
                    <script src="%s"></script>
                    <script>
                        var config = {
                            startOnLoad: true,
                            pie:{
                                    useMaxWidth:false,
                                    htmlLabels:true
                            }
                        };
                        mermaid.initialize(config);
                        mermaid.init(undefined, document.querySelectorAll('.language-mermaid'));
                    </script>
                """.printf (render);
                return mermaid;
            } else {
                return "";
            }
        }

        private void connect_signals () {
            decide_policy.connect ((decision, type) => {
                switch (type) {
                    case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
                        if (decision is WebKit.ResponsePolicyDecision) {
                            var policy = (WebKit.ResponsePolicyDecision) decision;
                            launch_browser (policy.request.get_uri ());
                        }
                        break;
                    case WebKit.PolicyDecisionType.RESPONSE:
                        if (decision is WebKit.ResponsePolicyDecision) {
                            var policy = (WebKit.ResponsePolicyDecision) decision;
                            launch_browser (policy.request.get_uri ());
                            return false;
                        }
                        break;
                    case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
                        break;
                }

                return true;
            });

            load_changed.connect ((event) => {
                if (event == WebKit.LoadEvent.FINISHED) {
                    var rectangle = get_window_properties ().get_geometry ();
                    set_size_request (rectangle.width, rectangle.height);
                }
            });
        }

        private void launch_browser (string url) {
            if (!url.contains ("/embed/")) {
                try {
                    AppInfo.launch_default_for_uri (url, null);
                } catch (Error e) {
                    warning ("No app to handle urls: %s", e.message);
                }
                stop_loading ();
            }
        }

        public void update_html_view () {
            string processed_mk;
            string title, date;
            processed_mk = Services.FileManager.get_yamlless_markdown(
                buf.text,
                0,                                  // Cap number of lines
                out title,
                out date,
                true,                               // Include empty lines
                true,                               // H1 title:
                false                               // Include date
            );

            var mkd = new Markdown.Document.from_gfm_string (processed_mk.data,
                Markdown.DocumentFlags.TOC +
                Markdown.DocumentFlags.AUTOLINK +
                Markdown.DocumentFlags.EXTRA_FOOTNOTE +
                Markdown.DocumentFlags.DLEXTRA +
                Markdown.DocumentFlags.FENCEDCODE +
                Markdown.DocumentFlags.GITHUBTAGS +
                Markdown.DocumentFlags.LATEX +
                Markdown.DocumentFlags.URLENCODEDANCHOR +
                Markdown.DocumentFlags.NOSTYLE +
                Markdown.DocumentFlags.EXPLICITLIST
            );

            mkd.compile (
                Markdown.DocumentFlags.TOC +
                Markdown.DocumentFlags.AUTOLINK +
                Markdown.DocumentFlags.EXTRA_FOOTNOTE +
                Markdown.DocumentFlags.DLEXTRA +
                Markdown.DocumentFlags.FENCEDCODE +
                Markdown.DocumentFlags.GITHUBTAGS +
                Markdown.DocumentFlags.LATEX +
                Markdown.DocumentFlags.URLENCODEDANCHOR +
                Markdown.DocumentFlags.NOSTYLE +
                Markdown.DocumentFlags.EXPLICITLIST
            );

            mkd.get_document (out processed_mk);
            string highlight = set_highlight ();
            string cheaders = set_center_headers ();
            string latex = set_latex ();
            string mermaid = set_mermaid ();
            string font = set_font_stylesheet ();
            string style = set_stylesheet ();
            string md = process_plugins (processed_mk);

            bool focus_active = Quilter.Application.gsettings.get_boolean ("focus-mode");
            bool typewriter_active = Quilter.Application.gsettings.get_boolean ("typewriter-scrolling");
            if (focus_active && typewriter_active) {
                style += """
                html {
                    padding-top: 50%;
                    padding-bottom: 50%;
                }
                """;
            } else {
                style += """
                html {
                    padding-bottom: 10%;
                }
                """;
            }

            html = """
            <!doctype html>
            <html>
                <head>
                    <meta charset="utf-8">
                    <style>%s</style>
                    %s
                    %s
                    <link rel="stylesheet" href="%s"/>
                    <link rel="stylesheet" href="%s"/>
                </head>
                <body>
                    %s
                    <div class="markdown-body">
                        %s
                    </div>
                </body>
            </html>""".printf (style, highlight, latex, font, cheaders, mermaid, md);

            this.load_html (html, "file:///");
        }

        private string process_plugins (string raw_mk) {
            var lines = raw_mk.split ("\n");
            string build = "";
            foreach (var line in lines) {
                bool found = false;
                foreach (var plugin in Plugins.PluginManager.get_instance ().get_plugs ()) {
                    if (plugin.has_match (line)) {
                        build = build + plugin.convert (line) + "\n";
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    build = build + line + "\n";
                }
            }

            return build;
        }
    }
}
