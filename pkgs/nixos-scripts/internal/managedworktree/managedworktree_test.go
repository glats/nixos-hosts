package managedworktree

import (
	"path/filepath"
	"sync"
	"testing"
	"time"
)

func TestTaskIDAndPaths(t *testing.T) {
	for _, id := range []string{"a", "task-1", "a0-" + string(make([]byte, 0))} {
		if !ValidTaskID(id) {
			t.Errorf("ValidTaskID(%q) = false", id)
		}
	}
	for _, id := range []string{"", "A", "a_b", "-task", "a/branch", string(make([]byte, 64))} {
		if ValidTaskID(id) {
			t.Errorf("ValidTaskID(%q) = true", id)
		}
	}
	if got := BranchFor("task-1"); got != "managed/task-1" {
		t.Fatalf("BranchFor() = %q", got)
	}
	if got := PathFor("/repo", "task-1"); got != filepath.Join("/repo", ".worktrees", "managed", "task-1") {
		t.Fatalf("PathFor() = %q", got)
	}
}

func TestMetadataTransitionsAndPersistence(t *testing.T) {
	dir := t.TempDir()
	record := Record{ID: "task", Branch: "managed/task", Path: "/repo/.worktrees/managed/task", BaseBranch: "master", BaseCommit: "abc", State: Active}
	if err := SaveRecord(dir, record); err != nil {
		t.Fatal(err)
	}
	got, err := LoadRecord(dir, "task")
	if err != nil || got != record {
		t.Fatalf("LoadRecord() = %#v, %v", got, err)
	}
	if err := Transition(&got, Ready); err != nil {
		t.Fatal(err)
	}
	if err := Transition(&got, Integrated); err != nil {
		t.Fatal(err)
	}
	if err := Transition(&got, Active); err == nil {
		t.Fatal("integrated record transitioned backwards")
	}
	if err := Transition(&record, Abandoned); err != nil {
		t.Fatal(err)
	}
	if err := Transition(&record, Integrated); err == nil {
		t.Fatal("abandoned record transitioned")
	}
}

func TestPortableLockSerializesAndReleases(t *testing.T) {
	dir := t.TempDir()
	first, err := AcquireLock(dir, 0)
	if err != nil {
		t.Fatal(err)
	}
	deferred := make(chan error, 1)
	go func() { _, err := AcquireLock(dir, 20*time.Millisecond); deferred <- err }()
	if err := <-deferred; err == nil {
		t.Fatal("second lock acquired while first held")
	}
	if err := first.Release(); err != nil {
		t.Fatal(err)
	}
	second, err := AcquireLock(dir, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	second.Release()
}

func TestConcurrentLockEventuallyAllowsOneAtATime(t *testing.T) {
	dir := t.TempDir()
	var wg sync.WaitGroup
	var mu sync.Mutex
	active := 0
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			lock, err := AcquireLock(dir, time.Second)
			if err != nil {
				t.Error(err)
				return
			}
			mu.Lock()
			active++
			if active != 1 {
				t.Error("lock was not exclusive")
			}
			mu.Unlock()
			time.Sleep(time.Millisecond)
			mu.Lock()
			active--
			mu.Unlock()
			lock.Release()
		}()
	}
	wg.Wait()
}
