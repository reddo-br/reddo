package com.reddit.newsokur.browser;

public class Path {
  public String getJarPath() {
    return getClass().getProtectionDomain().getCodeSource().getLocation().getPath();
  }
}

