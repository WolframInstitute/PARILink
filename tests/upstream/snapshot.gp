\\ Independent native-GP oracle. Opaque values go to a file, avoiding a huge
\\ byte vector on the PARI stack and the link's deliberate response-size limit.
auditoffset = 0;
auditbytes(s) = print1(Vecsmall(s));
auditsnapshot(z, depth = 0) = {
  my(t = type(z), dims, s, size);
  if(depth <= 32,
    if(t == "t_INT", print1("[\"i\",\"", z, "\"]"); return);
    if(t == "t_FRAC", print1("[\"q\",\"", numerator(z), "\",\"", denominator(z), "\"]"); return);
    if(t == "t_COMPLEX" && (type(real(z)) == "t_INT" || type(real(z)) == "t_FRAC") && (type(imag(z)) == "t_INT" || type(imag(z)) == "t_FRAC"),
      if(imag(z) == 0, auditsnapshot(real(z)); return);
      print1("[\"c\","); auditsnapshot(real(z)); print1(","); auditsnapshot(imag(z)); print1("]"); return);
    if(t == "t_STR", print1("[\"s\","); auditbytes(z); print1("]"); return);
    if((t == "t_VEC" || t == "t_COL" || t == "t_VECSMALL") && #z <= 10000,
      print1("[\"v\",[");
      for(j = 1, #z, if(j > 1, print1(",")); auditsnapshot(z[j], depth + 1));
      print1("]]"); return);
    if(t == "t_MAT",
      dims = matsize(z);
      if(dims[1] * dims[2] <= 10000,
        auditsnapshot(vector(dims[1], j, vector(dims[2], k, z[j,k])), depth + 1); return))
  );
  s = Str(z); size = #s + 1;
  write("audit-objects.txt", s);
  print1("[\"o\",\"", t, "\",", auditoffset, ",", size, "]");
  auditoffset += size;
};
setrand(1);
