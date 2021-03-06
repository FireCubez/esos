{
	function defer(value) {
		let obj = {type: "deferred", value};
		(peg$parse.deferred || (peg$parse.deferred = [])).push(obj);
		return obj;
	}
	function makeLabelGetCode(label) {
		return `
		if(global.${label} !== undefined) {
			if(global.$__ismacro__${label} !== undefined) {
				let err = new Error();
				err.p = true;
				err.location = ${JSON.stringify(location())};
				err.file = currentFile;
				err.message = "Tried to reference \`${deobf(label)}\`, which is a macro, not a label\\n    ## compiler details:\\n        - mangled name: \`${label}\`\\n        - $__ismacro__: \`" + $__ismacro__${label} + "\`";
				throw err;
			} else {
				intoBytes(${label});
			}
		} else {
			let err = new Error();
			err.p = true;
			err.location = ${JSON.stringify(location())};
			err.file = currentFile;
			err.message = "Label \`${deobf(label)}\` is not defined\\n    ## compiler details:\\n        - mangled name: \`${label}\`\\n        - $__ismacro__: \`" + $__ismacro__${label} + "\`";
			throw err;
		}`;
	}
	function makeLabelCode(label) {
		return `global.${label} = currentPos; []`;
	}
	function makeMacroCreation(name, c) {
		return `
		global.$__macro__nopchange__${name} = ${c};
		global.${name} = (...ar) => {
			let savePos = currentPos;
			let r = global.$__macro__nopchange__${name}(...ar);
			let a = arraywrap(r);
			if(currentPos > savePos + a.length) console.warn(\`\
WARNING: currentPos was incremented more than the result length, \
are you incorrectly changing currentPos?
    - additional info:
      - the error occured while evaluating a macro
macro error: ${name}\`);
			currentPos = savePos + a.length;
			return a;
		};
		global.$__ismacro__${name} = true; []`;
	}
	function makeMacroUseCode(name, args) {
		return `
		if(global.${name} !== undefined) {
			if(global.$__ismacro__${name} !== undefined) {
				${name}(${args});
			} else {
				let err = new Error();
				err.p = true;
				err.location = ${JSON.stringify(location())};
				err.file = currentFile;
				err.message = "Tried to call \`${deobf(name)}\`, which is a label, not a macro\\n    ## compiler details:\\n        - mangled name: \`${name}\`\\n        - $__ismacro__: \`" + global.$__ismacro__${name} + "\`";
				throw err;
			}
		} else {
			let err = new Error();
			err.p = true;
			err.location = ${JSON.stringify(location())};
			err.file = currentFile;
			err.message = "Macro \`${deobf(name)}\` is not defined\\n    ## compiler details:\\n        - mangled name: \`${name}\`";
			throw err;
		}`;
	}
	function deobf(label) {
		return label.split("___").pop();
	}
}

Program "program" = head:(_ i:Item {return i})? tail:(__ s:Item {return s})* _ {
	if(head == null) {
		return {items: [], deferred: []};
	}
	let newItems = [];
	let items = [head].concat(tail);
	for(let item of items) {
		if(item.label) {
			newItems.push({type: "js", value: makeLabelCode(item.label)});
		}
		newItems.push(item.item);
	}
	return {items: newItems, deferred: peg$parse.deferred || []};
}

Item "item" = label:(l:Id _ ":" _ {return l})? item:(Number / Label / JSExpr / DeferredJSExpr / MacroUse / Macro) {
	return {label, item};
}

Number "integer" = "-"? ("0x" [0-9A-Fa-f]+ / "0o" [0-7]+ / "0b" [01]+ / [0-9]+) {return {value: Number(text())}}

Label "label" = id:Id {
	return defer({type: "label", id, length: 4, code: makeLabelGetCode(id)});
}

JSExpr "JS expression" = "{" _ "{" x:Braced "}" _ "}" {
	return {type: "js", value: x};
}

DeferredJSExpr "deferred JS expression" = "{" _ "$" _ length:(n:Number {return n.value} / x:Braced {return x}) _ "{" code:Braced "}" _ "$" _ "}" {
	return defer({type: "djs", length, code});
}

Macro "macro definition" = "{" _ id:Id __ x:Braced "}" {
	return {type: "js", value: makeMacroCreation(id, x)};
}

MacroUse "macro invocation" = "<" _ id:Id _ "{" x:Braced "}" _ ">" {
	return {type: "js", value: makeMacroUseCode(id, x)};
}

Braced = ([^{}] / "{" Braced "}")* {return text()}

Id "identifier" = extern:("extern" __)? s:$([A-Za-z$_][A-Za-z0-9$_]*) {
	return extern ? s : `_M${peg$parse.obf}___${s}`;
}

__ "whitespace" = [ \t\r\n]+
_ "optional whitespace" = __?
