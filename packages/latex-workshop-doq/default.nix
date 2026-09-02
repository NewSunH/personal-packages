{
  doq,
  jq,
  vscode-extensions,
}:

vscode-extensions.james-yu.latex-workshop.overrideAttrs (old: {
  pname = "latex-workshop-doq";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ jq ];

  postInstall = (old.postInstall or "") + ''
    extension_dir="$out/share/vscode/extensions/James-Yu.latex-workshop"
    doq_dir="$extension_dir/viewer/doq"

    mkdir -p "$doq_dir"
    cp -r ${doq}/share/doq/. "$doq_dir/"
    chmod -R u+w "$doq_dir"

    jq --slurp '.[0] + .[1]' \
      ${./catppuccin.json} \
      "$doq_dir/lib/colors.json" \
      > "$doq_dir/lib/colors.json.new"
    mv "$doq_dir/lib/colors.json.new" "$doq_dir/lib/colors.json"

    substituteInPlace "$doq_dir/addon/app/config.js" \
      --replace-fail 'scheme: 0, tone: "0",' 'scheme: 0, tone: "1",' \
      --replace-fail 'flags: { shapesOn: true, imagesOn: true }' \
        'flags: { shapesOn: true, imagesOn: false }'

    substituteInPlace "$extension_dir/out/viewer/latexworkshop.js" \
      --replace-fail '//# sourceMappingURL=latexworkshop.js.map' \
        $'await import(\'../../doq/addon/doq.js\');\n//# sourceMappingURL=latexworkshop.js.map'
  '';
})
