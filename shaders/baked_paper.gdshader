shader_type canvas_item;
// The parchment, rendered once at load (see SheetBaker.bake_paper) and simply
// shown from then on — the procedural parchment shader is far too costly to
// run over the whole screen every frame.

uniform sampler2D paper_tex : filter_linear_mipmap;

void fragment() {
	COLOR = texture(paper_tex, UV);
}
