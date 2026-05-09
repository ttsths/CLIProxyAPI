package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestBootstrapConfigSeedPathPrefersNonEmptyConfig(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	configPath := filepath.Join(dir, "config.yaml")
	examplePath := filepath.Join(dir, "config.example.yaml")
	if err := os.WriteFile(configPath, []byte("port: 8317\n"), 0o600); err != nil {
		t.Fatalf("write config.yaml: %v", err)
	}
	if err := os.WriteFile(examplePath, []byte("port: 9999\n"), 0o600); err != nil {
		t.Fatalf("write config.example.yaml: %v", err)
	}

	got := bootstrapConfigSeedPath(dir)
	if got != configPath {
		t.Fatalf("expected config seed path %q, got %q", configPath, got)
	}
}

func TestBootstrapConfigSeedPathFallsBackToExample(t *testing.T) {
	t.Parallel()

	dir := t.TempDir()
	configPath := filepath.Join(dir, "config.yaml")
	examplePath := filepath.Join(dir, "config.example.yaml")
	if err := os.WriteFile(configPath, []byte("   \n"), 0o600); err != nil {
		t.Fatalf("write empty config.yaml: %v", err)
	}
	if err := os.WriteFile(examplePath, []byte("port: 8317\n"), 0o600); err != nil {
		t.Fatalf("write config.example.yaml: %v", err)
	}

	got := bootstrapConfigSeedPath(dir)
	if got != examplePath {
		t.Fatalf("expected example seed path %q, got %q", examplePath, got)
	}
}
