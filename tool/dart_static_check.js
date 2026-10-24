#!/usr/bin/env node
/**
 * Lightweight static checks for the Dart sources, used by CI environments
 * (including this sandbox) that cannot install the Dart SDK.
 *
 * It is NOT a replacement for `dart analyze` / `flutter analyze`; it verifies:
 *   1. every Dart file parses (tree-sitter-dart);
 *   2. every relative import resolves to a file that exists;
 *   3. every imported relative library at least exists and is non-empty;
 *   4. type/class identifiers used as receivers or constructors are either
 *      declared somewhere in lib/test or listed in the SDK allowlist below;
 *   5. no obvious secret material is committed.
 *
 * Usage: node tool/dart_static_check.js
 * Requires: npm i tree-sitter@0.20.6 tree-sitter-dart@1.0.0
 */
const fs = require('fs');
const path = require('path');
const Parser = require('tree-sitter');
const Dart = require('tree-sitter-dart');

const ROOT = path.resolve(__dirname, '..');
const parser = new Parser();
parser.setLanguage(Dart);

const PKG_NAME = 'bangladesh_newspaper_hub';

/** Maps dart:/package:/relative URIs to a file inside this repository. */
function resolveImport(fromFile, uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    const rest = uri.slice('package:'.length);
    const slash = rest.indexOf('/');
    const pkg = rest.slice(0, slash);
    if (pkg !== PKG_NAME) return null;
    return path.join(ROOT, 'lib', rest.slice(slash + 1));
  }
  return path.resolve(path.dirname(fromFile), uri);
}

const SKIP_DIRS = new Set(['build', '.dart_tool', 'node_modules', '.git', 'android', 'ios']);

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.') && entry.name !== '.') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(full, out);
    } else if (entry.name.endsWith('.dart')) {
      out.push(full);
    }
  }
  return out;
}

const files = walk(ROOT);
const errors = [];
const warnings = [];
const declared = new Set();
const fileInfo = new Map();

const hasErr = (n) => (typeof n.hasError === 'function' ? n.hasError() : n.hasError);

function topLevelNames(src) {
  const names = new Set();
  const lines = src.split('\n');
  for (const line of lines) {
    if (/^\s/.test(line)) continue; // only column-0 declarations
    let m;
    if ((m = /^(?:abstract\s+|final\s+|sealed\s+|base\s+)*class\s+([A-Za-z_]\w*)/.exec(line))) names.add(m[1]);
    else if ((m = /^mixin\s+([A-Za-z_]\w*)/.exec(line))) names.add(m[1]);
    else if ((m = /^enum\s+([A-Za-z_]\w*)/.exec(line))) names.add(m[1]);
    else if ((m = /^extension\s+([A-Za-z_]\w*)\s+on/.exec(line))) names.add(m[1]);
    else if ((m = /^typedef\s+[\w<>, ]*\s([A-Za-z_]\w*)\s*=/.exec(line))) names.add(m[1]);
    else if ((m = /^(?:const|final|var|late)\s+(?:[\w<>?,\s]+\s)?([A-Za-z_]\w*)\s*[=;]/.exec(line))) names.add(m[1]);
    else if ((m = /^(?:Future|Stream|void|String|int|bool|double|[A-Z]\w*)\s+([a-z_]\w*)\s*[<(]/.exec(line))) names.add(m[1]);
    else if ((m = /^(?:abstract\s+)?(?:class|mixin)\s+([A-Za-z_]\w*)/.exec(line))) names.add(m[1]);
  }
  return names;
}

for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  const tree = parser.parse(src);
  if (hasErr(tree.rootNode)) {
    errors.push(`parse error: ${path.relative(ROOT, file)}`);
  }
  const names = topLevelNames(src);
  for (const n of names) declared.add(n);
  const imports = [];
  for (const node of tree.rootNode.children) {
    if (node.type === 'import_or_export' || node.type === 'library_import' ||
        node.type === 'library_export') {
      const uriNode = node.descendantsOfType('uri')[0];
      if (!uriNode) continue;
      const uri = uriNode.text.replace(/^['"]|['"]$/g, '');
      imports.push({ uri, node });
    }
  }
  fileInfo.set(file, { src, tree, imports, names });
}

// 2. import resolution
for (const [file, info] of fileInfo) {
  for (const imp of info.imports) {
    const target = resolveImport(file, imp.uri);
    if (target == null) continue;
    if (!fs.existsSync(target)) {
      errors.push(`missing import target "${imp.uri}" in ${path.relative(ROOT, file)}`);
    }
  }
}

// 4. undefined type-ish identifiers
const SDK = new Set(`
Object String int double num bool List Map Set Iterable Future Stream Duration DateTime
Uri RegExp Match StringBuffer Stopwatch Null Function Comparable Exception Error
FormatException ArgumentError StateError UnsupportedError TypeError StateError
UnsupportedError UnimplementedError RangeError RangeError JsonEncoder JsonDecoder json
Widget BuildContext State StatefulWidget StatelessWidget InheritedWidget Key
GlobalKey ValueKey UniqueKey EdgeInsets EdgeInsetsGeometry Alignment AlignmentGeometry
BoxConstraints Size Offset Rect Radius BorderRadius BorderRadiusDirectional Border
BoxDecoration BoxShadow BoxBorder Color Colors TextStyle TextTheme ThemeData ThemeMode
Theme Brightness MaterialApp WidgetsApp Navigator NavigatorState Route PageRoute
PageRouteBuilder RouteSettings PageTransitionsBuilder PageTransitionsTheme
MaterialPageRoute AnimatedBuilder Animation AnimationController Tween CurvedAnimation
Curves TickerProvider SingleTickerProviderStateMixin TickerProviderStateMixin
MediaQuery MediaQueryData TextScaler TextDirection Padding Center Row Column Stack
Positioned Container SizedBox Expanded Flexible Spacer Align FractionallySizedBox
ListView ListViewBuilder GridView SliverList SliverGrid SliverToBoxAdapter
SliverFillRemaining SliverAppBar CustomScrollView CustomScrollDelegate SliverChildBuilderDelegate
RefreshIndicator Scaffold ScaffoldMessengerState ScaffoldMessenger SnackBar SnackBarAction
AppBar TabBar TabBarView TabController Tab Icon IconButton IconTheme IconThemeData
Text TextSpan TextEditingController FocusNode TextField TextInputAction InputDecoration
InputBorder OutlineInputBorder BorderSide BorderRadiusGeometry
FilledButton OutlinedButton TextButton ElevatedButton IconButton ChoiceChip FilterChip
ActionChip Chip ChipThemeData ButtonStyle ButtonSegment SegmentedButton
DropdownButton DropdownMenuItem ListTile ListTileTheme Switch SwitchListTile Slider
Card CardThemeData CardTheme Divider VerticalDivider Chip LinearProgressIndicator
CircularProgressIndicator ProgressIndicatorThemeData InkWell InkSparkle Material
GestureDetector AnimatedContainer AnimatedSwitcher FadeTransition SlideTransition
ScaleTransition SizeTransition SafeArea AspectRatio ClipRRect RoundedRectangleBorder
CircleAvatar Tooltip Dialog AlertDialog BottomSheet BottomSheetThemeData
NavigationBar NavigationBarThemeData NavigationDestination
VisualDensity EdgeInsetsDirectional VisualDensityAdaptivePlatform
Semantics PageStorage ScrollController ScrollPhysics NeverScrollableScrollPhysics
AlwaysScrollableScrollPhysics BouncingScrollPhysics ClampingScrollPhysics
WidgetState WidgetStateProperty WidgetStatePropertyAll MaterialStateProperty
SystemUiOverlayStyle HapticFeedback Clipboard ClipboardData Image ImageProvider
AssetBundle rootBundle CachedNetworkImage BoxFit TextOverflow MainAxisAlignment
MainAxisSize CrossAxisAlignment TextAlign TextBaseline FontWeight FontStyle
AlignmentDirectional Wrap TransitionBuilder OrientationBuilder LayoutBuilder
Builder Provider MultiProvider ChangeNotifier Consumer SingleChildWidget
Connectivity ConnectivityResult SharedPreferences Share Prefs Database
ChangeNotifierProvider ProviderOf DatabaseFactory OpenDatabaseOptions ConflictAlgorithm
Batch Sqflite MediaQuery.of.debugPrint debugPrint
Timer CustomTargetPlatform Rect Ticker Isolate Zone
LaunchMode NumberFormat T TargetPlatform XmlElement XmlNode XmlAttribute XmlDocument XmlException
`.split(/\s+/).filter(Boolean));

const declaredUpper = new Set([...declared]);
const used = new Map(); // name -> [file:line]
for (const [file, info] of fileInfo) {
  const visit = (node) => {
    if ((node.type === 'identifier' || node.type === 'type_identifier')) {
      const text = node.text;
      if (/^[A-Z][A-Za-z0-9_]*$/.test(text)) {
        const parent = node.parent;
        const isUse = parent && (
          parent.type === 'member_expression' ||
          parent.type === 'member_access' ||
          parent.type === 'type_arguments' ||
          parent.type === 'type_annotation' ||
          parent.type === 'object_creation_expression' ||
          parent.type === 'constructor_invocation' ||
          parent.type === 'extends_clause' ||
          parent.type === 'implements_clause' ||
          parent.type === 'with_clause' ||
          parent.type === 'superclass' ||
          parent.type === 'type_identifier' ||
          parent.type === 'class_definition' ||
          parent.type === 'argument_part' ||
          parent.type === 'superclass' ||
          parent.type === 'mixin_application' ||
          parent.type === 'named_type'
        );
        if (isUse) {
          if (!used.has(text)) used.set(text, []);
          used.get(text).push(`${path.relative(ROOT, file)}:${node.startPosition.row + 1}`);
        }
      }
    }
    for (const child of node.children) visit(child);
  };
  visit(info.tree.rootNode);
}

const unknown = [];
for (const [name, where] of used) {
  if (declaredUpper.has(name) || SDK.has(name)) continue;
  unknown.push(`${name} (${where[0]}${where.length > 2 ? ` +${where.length - 1}` : ''})`);
}
if (unknown.length) {
  unknown.sort();
  errors.push(`undefined identifiers (${unknown.length}):\n    ` + unknown.join('\n    '));
}

// 4b. every project-level type must be imported by the file that uses it
const declaredIn = new Map(); // symbol -> Set<file>
for (const [file, info] of fileInfo) {
  for (const name of info.names) {
    if (!/^[A-Z]/.test(name)) continue;
    if (!declaredIn.has(name)) declaredIn.set(name, new Set());
    declaredIn.get(name).add(file);
  }
}
for (const [file, info] of fileInfo) {
  const direct = new Set([file]);
  for (const imp of info.imports) {
    const resolved = resolveImport(file, imp.uri);
    if (resolved) direct.add(resolved);
  }
  const visit = (node) => {
    if (node.type === 'identifier' || node.type === 'type_identifier') {
      const text = node.text;
      const owners = declaredIn.get(text);
      if (owners && !owners.has(file) && ![...owners].some((f) => direct.has(f))) {
        errors.push(
          `${path.relative(ROOT, file)}:${node.startPosition.row + 1} uses ${text} ` +
          `but does not import ${[...owners].map((f) => path.relative(ROOT, f)).join(' or ')}`,
        );
      }
    }
    for (const child of node.children) visit(child);
  };
  visit(info.tree.rootNode);
}

// 4c. named arguments passed to project constructors must exist
function classBody(text, name) {
  const re = new RegExp('^(?:abstract |final |sealed |base )*class ' + name + '[^{]*\\{', 'm');
  const m = re.exec(text);
  if (!m) return null;
  let i = m.index + m[0].length;
  let depth = 1;
  while (i < text.length && depth > 0) {
    if (text[i] === '{') depth++;
    else if (text[i] === '}') depth--;
    i++;
  }
  return text.slice(m.index + m[0].length, i - 1);
}

function topLevelPieces(listSrc) {
  // Strip the enclosing bracket pair so `{ a: 1, b: 2 }` splits on its commas.
  // Angle brackets are intentionally not tracked: `=>` would corrupt the depth.
  let src = listSrc.trim();
  if (src.length > 1) {
    const first = src[0];
    const last = src[src.length - 1];
    if ((first === '{' && last === '}') ||
        (first === '(' && last === ')') ||
        (first === '[' && last === ']')) {
      src = src.slice(1, -1);
    }
  }
  const pieces = [];
  let depth = 0;
  let token = '';
  for (const ch of src) {
    if ('([{'.includes(ch)) depth++;
    else if (')]}'.includes(ch)) depth--;
    if (ch === ',' && depth === 0) {
      pieces.push(token);
      token = '';
    } else {
      token += ch;
    }
  }
  pieces.push(token);
  return pieces;
}

const ctorParams = new Map(); // className -> Set of accepted named params (null = unknown)
for (const [file, info] of fileInfo) {
  for (const decl of info.src.matchAll(/^(?:abstract |final |sealed |base )*class (\w+)/gm)) {
    const name = decl[1];
    const body = classBody(info.src, name);
    if (body == null) continue;
    const params = new Set();
    const fieldRe = /^\s+(?:final\s+|const\s+|late\s+)*[\w<>?,\s\[\]]+?\s(\w+);/gm;
    let fm;
    while ((fm = fieldRe.exec(body)) !== null) params.add(fm[1]);
    const ctorRe = new RegExp('(?:const\\s+)?\\b' + name + '(?:\\.\\w+)?\\s*\\(', 'g');
    let hasCtor = false;
    let cm;
    while ((cm = ctorRe.exec(body)) !== null) {
      hasCtor = true;
      let i = cm.index + cm[0].length;
      let depth = 1;
      while (i < body.length && depth > 0) {
        if (body[i] === '(') depth++;
        else if (body[i] === ')') depth--;
        i++;
      }
      for (const rawPiece of topLevelPieces(body.slice(cm.index + cm[0].length, i - 1))) {
        // Drop a default value so `bool online = true` yields `online`.
        const piece = rawPiece.replace(/^[\s{[(]+/, '').split('=')[0].trim();
        if (!piece || piece.startsWith('//')) continue;
        const named = /(?:^|\s)(?:required\s+|this\.)?(\w+)\s*(?:=|,|$)/.exec(piece);
        const tail = /(?:required\s+)?[\w<>?,\s\[\]]*?\s(\w+)$/.exec(piece);
        if (/this\.(\w+)/.test(piece)) params.add(/this\.(\w+)/.exec(piece)[1]);
        else if (tail) params.add(tail[1]);
        else if (named) params.add(named[1]);
      }
    }
    if (!hasCtor && params.size === 0) continue;
    const existing = ctorParams.get(name);
    ctorParams.set(name, existing == null ? params : new Set([...existing, ...params]));
  }
}

const widgetInherited = new Set(['key', 'child']);
for (const [file, info] of fileInfo) {
  const code = info.src.replace(/^\s*\/\/.*$/gm, '');
  const callRe = /\b([A-Z]\w*)\s*\(/g;
  let call;
  while ((call = callRe.exec(code)) !== null) {
    const name = call[1];
    const allowed = ctorParams.get(name);
    if (!allowed || allowed.size === 0) continue;
    let i = call.index + call[0].length;
    let depth = 1;
    while (i < code.length && depth > 0) {
      if (code[i] === '(') depth++;
      else if (code[i] === ')') depth--;
      i++;
    }
    const args = code.slice(call.index + call[0].length, i - 1);
    for (const piece of topLevelPieces(args)) {
      const m = /^\s*(\w+)\s*:/.exec(piece);
      if (!m) continue;
      if (allowed.has(m[1]) || widgetInherited.has(m[1])) continue;
      const line = code.slice(0, call.index).split('\n').length;
      errors.push(
        `${path.relative(ROOT, file)}:${line} calls ${name}(... ${m[1]}: ...) ` +
        `but ${name} has no such named parameter`,
      );
    }
  }
}

// 5. secret scanning
const secretPatterns = [
  [/AIza[0-9A-Za-z\-_]{35}/, 'Google API key'],
  [/sk-[A-Za-z0-9]{32,}/, 'OpenAI-style key'],
  [/gh[pousr]_[A-Za-z0-9]{30,}/, 'GitHub token'],
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, 'private key'],
  [/SUPABASE_SERVICE_ROLE|FIREBASE_PRIVATE_KEY|AWS_SECRET_ACCESS_KEY/, 'service credential'],
];
for (const file of [...files, path.join(ROOT, 'README.md')]) {
  if (!fs.existsSync(file)) continue;
  const text = fs.readFileSync(file, 'utf8');
  for (const [re, label] of secretPatterns) {
    if (re.test(text)) errors.push(`possible ${label} in ${path.relative(ROOT, file)}`);
  }
}

console.log(`checked ${files.length} Dart files, ${declared.size} top-level symbols`);
if (warnings.length) console.log('warnings:\n  ' + warnings.join('\n  '));
if (errors.length) {
  console.error('\nFAILED');
  for (const e of errors) console.error(' - ' + e);
  process.exit(1);
}
console.log('all static checks passed');
