# Team Collaboration & Branching Guide

Welcome! To keep our repository clean, stable, and free of code conflicts, we follow a feature-branch workflow.

## 🚨 The Gold Rule of Our Repository
> [!WARNING]
> **The `main` branch is protected.** Direct pushes to `main` are disabled. All work must happen on a feature branch and be merged via a GitHub Pull Request (PR).

---

> [!IMPORTANT]
> please copy the file PLEASE_USE_THIS_GITIGNORE.template to .gitignore
> in your local Repository
> to prevent version controlling junk files.

---

## 🛠️ Step-by-Step Feature Workflow

### 1. Sync Your Local `main`
Before starting any new feature, fix, or document update, ensure your local `main` is up to date:
```bash
git checkout main
git pull origin main
```

> [!TIP]
> The *most important* habit is **pulling main regularly**  into your local feature branch via 
> ```bash 
> git pull origin main
> ```
> Resolving conflicts locally **virtually eliminates** merge conflicts when opening your Pull Request online (as long as ```main``` doesn't change before your PR is merged).

---
### 2. Create a Dedicated Feature Branch
Create and switch to a descriptive branch for what you are building:
```bash
git checkout -b feature/your-feature-name
# Examples: feature/add-login, fix/header-padding, docs/contributing-guide
```

### 3. Work, Save, and Commit
Build your feature locally and commit your changes in logical steps:
```bash
git add .
git commit -m "Add concise summary of what you built"
```

### 4. Push Your Branch to GitHub
Push your feature branch to the remote repository:
```bash
git push origin feature/your-feature-name
```

### 5. Open and Merge a Pull Request
1. Go to our repository on **GitHub.com**.
2. Click the **Compare & pull request** button.
3. Add a quick title and summary of your changes, then click **Create pull request**.
4. Review the diffs, then click **Merge pull request** $\rightarrow$ **Confirm merge**.
5. Delete the feature branch on GitHub after merging to keep the repo clean.

---

## 💡 Best Practices to Prevent Merge Conflicts

* **Pull `main` Frequently:** If `main` updates while you are working on your feature branch, pull those updates early:
  ```bash
  git checkout feature/your-feature-name
  git pull origin main
  ```
* **Keep Branches Small:** Complete tasks in 1–2 days so branches merge quickly before `main` moves forward too much.
* **Never Force Push:** Avoid running `git push --force`.
* **Separate Files:** Coordinate with teammates so you avoid editing the exact same lines of code in the same file simultaneously.


# 📝 TODO

- Session artiges zeug rausnehmen aus nicht-session -> Die Kategorien Buttons sollen zu reinen "Overview-Screns" führen.
- Session-Feature für Quiz
- Viele ähnliche Quizfragen, großer Aufgabenpool, ähnliche (sogar nur andere Zahlen) Fragen sollen rotiert werden.
- Langzeitstatistik (mit Import / Export)
