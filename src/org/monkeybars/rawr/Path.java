package org.monkeybars.rawr;

public class Path {
  public String getJarPath() {
    return getClass().getProtectionDomain().getCodeSource().getLocation().getPath();
  }
}

