InferSudoku is a Coffeescript project to solve Sudoku puzzles using human-level
inference. It was written as a final project for COMP360 - Topics in Artificial
Intelligence at Wesleyan University in the Spring 2011 semester. The following
are instructions that were provided to the instructor when the project was
submitted for a grade.

---------------------------

This project is written in Coffeescript, a language which compiles to
javascript.

The original source (in coffeescript) is included along with compiled javascript
files which will run in a web browser; both types of files are included in the
js/ directory.

The coffeescript source files are also viewable in a pretty annotated source
format (via Docco) in HTML documents in the docs/ directory; these should be
viewable if you navigate a web browser to these HTML files.

The CSS for the HTML page was written in SASS, a language which compiles to
CSS. The compiled CSS and the source SASS are both provided in the css/ directory.

To view the app, navigate to html/sudoku.html in a web browser (preferrably
Chrome, the app was tested solely in Chrome and I did not have time to test it
in other browsers, so it may look funny or do funny things).

Both Coffeescript and SASS have the ability to be compiled by the browser
instead of beforehand, but it involves including the appropriate compiler
javascript files. If the grader would prefer this so the source code can be
tinkered with without recompiling each time, then let me know and I can set up
with this model instead.

The bookmarklet used to gather sudoku data was as follows:
javascript:(function(){var s="";for(i=0;i<9;i++){for(j=0;j<9;j++){var v=document.getElementById('f'+i+j).value;s+=v==""?".":v}s+="\n";}var pre=document.createElement('pre');pre.innerHTML=s;var body=document.getElementsByTagName('body')[0];body.insertBefore(pre,body.children[0]);})()
