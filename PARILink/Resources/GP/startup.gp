\\ PARILink's private GP bridge. No user startup file or downloads are needed.
parilinkobjects = Map();
parilinknext = 0;

parilinkstring(s) = Str("[\"s\",", Vec(Vecsmall(s)), "]");

parilinkreference(x) = {
  parilinknext++;
  mapput(parilinkobjects, parilinknext, x);
  Str("[\"o\",", parilinknext, ",\"", type(x), "\"]");
};

parilinkencode(x, depth = 0, references = 1) = {
  my(t = type(x), dims);
  if(depth > 32, return(if(references, parilinkreference(x), "[\"u\"]")));
  if(t == "t_INT", return(Str("[\"i\",\"", x, "\"]")));
  if(t == "t_FRAC", return(Str("[\"q\",\"", numerator(x), "\",\"", denominator(x), "\"]")));
  if(t == "t_STR", return(parilinkstring(x)));
  if(t == "t_COMPLEX" && (type(real(x)) == "t_INT" || type(real(x)) == "t_FRAC") && (type(imag(x)) == "t_INT" || type(imag(x)) == "t_FRAC"),
    return(Str("[\"c\",", parilinkencode(real(x)), ",", parilinkencode(imag(x)), "]")));
  if((t == "t_VEC" || t == "t_COL" || t == "t_VECSMALL" || t == "t_LIST") && #x <= 10000,
    return(Str("[\"v\",[", strjoin(vector(#x, i, parilinkencode(x[i], depth + 1, references)), ","), "]]")));
  if(t == "t_MAT",
    dims = matsize(x);
    if(dims[1] * dims[2] <= 10000,
      return(parilinkencode(vector(dims[1], i, vector(dims[2], j, x[i,j])), depth + 1, references))));
  if(references, parilinkreference(x), "[\"u\"]");
};

parilinkrequest(code, mode, marker) = {
  my(value, result);
  iferr(
    value = eval(code);
    result = if(mode == "Object", parilinkreference(value),
      if(mode == "String", parilinkstring(Str(value)), parilinkencode(value, 0, mode != "Copy")));
    result = Str("[\"ok\",", result, "]"),
    error,
    result = Str("[\"error\",", parilinkstring(errname(error)), ",", parilinkstring(Str(error)), "]")
  );
  print1("\n", marker, result, "\n");
};
