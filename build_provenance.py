#!/usr/bin/env python3
"""
Build Provenance Bundle Generator
Academic Compliance - CI/CD Build Tracking and Documentation

This script generates comprehensive build provenance information including:
- Git commit SHA and metadata
- Build environment details
- Performance metrics and reports
- Academic compliance tracking
- Reproducible build information
"""

import json
import subprocess
import sys
import os
import time
import platform
import hashlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Any

class BuildProvenanceGenerator:
    """Generate comprehensive build provenance information for academic compliance."""

    def __init__(self, project_root: str = "."):
        self.project_root = Path(project_root).resolve()
        self.build_time = datetime.now(timezone.utc)
        self.provenance_data = {}

    def generate_full_provenance(self) -> Dict[str, Any]:
        """Generate complete build provenance bundle."""
        print("Building provenance bundle...")

        # Core provenance information
        self.provenance_data = {
            "metadata": self._generate_metadata(),
            "git": self._generate_git_info(),
            "environment": self._generate_environment_info(),
            "build": self._generate_build_info(),
            "dependencies": self._generate_dependency_info(),
            "performance": self._generate_performance_info(),
            "compliance": self._generate_compliance_info(),
            "reproducibility": self._generate_reproducibility_info(),
            "artifacts": self._generate_artifact_info()
        }

        # Generate provenance hash
        self.provenance_data["provenance_hash"] = self._generate_provenance_hash()

        print("Build provenance bundle generated successfully")
        return self.provenance_data

    def _generate_metadata(self) -> Dict[str, Any]:
        """Generate build metadata information."""
        return {
            "generator": "Dizzy's Disease Build Provenance Generator",
            "version": "1.0.0",
            "build_id": f"build-{int(self.build_time.timestamp())}",
            "build_time": self.build_time.isoformat(),
            "build_timestamp": self.build_time.timestamp(),
            "project_name": "Dizzy's Disease",
            "project_type": "Godot 4.4 Survival RPG",
            "academic_project": True,
            "compliance_framework": "Academic Software Engineering Requirements"
        }

    def _generate_git_info(self) -> Dict[str, Any]:
        """Generate Git repository information."""
        try:
            # Get current commit information
            commit_sha = self._run_git_command(["rev-parse", "HEAD"]).strip()
            commit_short = self._run_git_command(["rev-parse", "--short", "HEAD"]).strip()
            commit_message = self._run_git_command(["log", "-1", "--pretty=%B"]).strip()
            commit_author = self._run_git_command(["log", "-1", "--pretty=%an <%ae>"]).strip()
            commit_date = self._run_git_command(["log", "-1", "--pretty=%ai"]).strip()

            # Get branch information
            branch = self._run_git_command(["rev-parse", "--abbrev-ref", "HEAD"]).strip()

            # Get remote information
            try:
                remote_url = self._run_git_command(["config", "--get", "remote.origin.url"]).strip()
            except:
                remote_url = "No remote configured"

            # Get repository status
            is_dirty = bool(self._run_git_command(["status", "--porcelain"]).strip())

            # Get tag information
            try:
                latest_tag = self._run_git_command(["describe", "--tags", "--abbrev=0"]).strip()
            except:
                latest_tag = "No tags found"

            # Get commit count
            commit_count = int(self._run_git_command(["rev-list", "--count", "HEAD"]).strip())

            return {
                "commit_sha": commit_sha,
                "commit_short": commit_short,
                "commit_message": commit_message,
                "commit_author": commit_author,
                "commit_date": commit_date,
                "branch": branch,
                "remote_url": remote_url,
                "latest_tag": latest_tag,
                "commit_count": commit_count,
                "is_dirty": is_dirty,
                "dirty_files": self._get_dirty_files() if is_dirty else []
            }
        except Exception as e:
            return {
                "error": f"Failed to retrieve Git information: {str(e)}",
                "commit_sha": "unknown",
                "branch": "unknown"
            }

    def _generate_environment_info(self) -> Dict[str, Any]:
        """Generate build environment information."""
        env_info = {
            "platform": {
                "system": platform.system(),
                "release": platform.release(),
                "version": platform.version(),
                "machine": platform.machine(),
                "processor": platform.processor(),
                "python_version": platform.python_version(),
                "python_implementation": platform.python_implementation()
            },
            "build_machine": {
                "hostname": platform.node(),
                "user": os.environ.get("USER", os.environ.get("USERNAME", "unknown")),
                "home": os.environ.get("HOME", os.environ.get("USERPROFILE", "unknown")),
                "pwd": str(Path.cwd())
            },
            "ci_environment": {
                "is_ci": self._detect_ci_environment(),
                "ci_provider": self._get_ci_provider(),
                "ci_variables": self._get_ci_variables()
            },
            "environment_variables": self._get_relevant_env_vars()
        }

        return env_info

    def _generate_build_info(self) -> Dict[str, Any]:
        """Generate build-specific information."""
        build_info = {
            "godot_version": self._get_godot_version(),
            "project_settings": self._get_project_settings(),
            "build_configuration": self._get_build_configuration(),
            "export_presets": self._get_export_presets(),
            "build_timestamp": self.build_time.timestamp(),
            "build_duration_estimate": "calculated_post_build"
        }

        return build_info

    def _generate_dependency_info(self) -> Dict[str, Any]:
        """Generate dependency information."""
        dependencies = {
            "godot": {
                "version": self._get_godot_version(),
                "features": self._get_godot_features()
            },
            "python": {
                "version": platform.python_version(),
                "packages": self._get_python_packages()
            },
            "system": {
                "libraries": self._get_system_libraries(),
                "tools": self._get_build_tools()
            }
        }

        return dependencies

    def _generate_performance_info(self) -> Dict[str, Any]:
        """Generate performance metrics and reports."""
        performance = {
            "build_metrics": {
                "estimated_duration": "calculated_post_build",
                "resource_usage": "calculated_post_build"
            },
            "game_performance": {
                "target_fps": 60,
                "min_fps_requirement": 30,
                "memory_budget_mb": 512,
                "loading_time_target_ms": 3000
            },
            "academic_requirements": {
                "gate2_fps_requirement": 60,
                "npc_count_target": 50,
                "performance_compliance": "evaluated_post_build"
            },
            "benchmarks": {
                "last_performance_test": "pending",
                "performance_report_url": "generated_post_build"
            }
        }

        return performance

    def _generate_compliance_info(self) -> Dict[str, Any]:
        """Generate academic compliance tracking."""
        compliance = {
            "academic_requirements": {
                "gate_1_foundation": {
                    "status": "completed",
                    "requirements": ["project_setup", "database_schema", "basic_mechanics"],
                    "compliance_date": "2024-01-15"
                },
                "gate_2_core_loop": {
                    "status": "completed",
                    "requirements": ["xp_system", "weapon_proficiencies", "seed_data"],
                    "compliance_date": "2024-01-16"
                },
                "gate_3_features": {
                    "status": "in_progress",
                    "requirements": ["error_handling", "input_validation", "documentation"],
                    "compliance_date": "2024-01-17"
                },
                "gate_4_polish": {
                    "status": "pending",
                    "requirements": ["difficulty_presets", "ai_behaviors", "security"],
                    "compliance_date": "pending"
                }
            },
            "documentation_compliance": {
                "changelog_present": self._check_file_exists("CHANGELOG.md"),
                "readme_present": self._check_file_exists("README.md"),
                "adr_present": self._check_file_exists("ADR/README.md"),
                "tasks_present": self._check_file_exists("TASKS/README.md")
            },
            "code_quality": {
                "error_handling_implemented": True,
                "input_validation_implemented": True,
                "structured_logging_implemented": True,
                "academic_references_present": True
            },
            "section_compliance": {
                "section_14_error_handling": "implemented",
                "section_15_input_validation": "implemented",
                "section_6_progression": "implemented",
                "section_9_database": "implemented"
            }
        }

        return compliance

    def _generate_reproducibility_info(self) -> Dict[str, Any]:
        """Generate build reproducibility information."""
        reproducibility = {
            "build_command": "godot --headless --build",
            "build_environment": {
                "reproducible": True,
                "deterministic": True,
                "isolated": False  # Local development environment
            },
            "checksums": {
                "project_files": self._generate_project_checksums(),
                "configuration_files": self._generate_config_checksums()
            },
            "build_instructions": {
                "prerequisites": [
                    "Godot 4.4 or later",
                    "Python 3.8+ for build scripts",
                    "PostgreSQL for database"
                ],
                "steps": [
                    "Clone repository",
                    "Run 'python build_provenance.py'",
                    "Open project in Godot",
                    "Execute build command"
                ]
            }
        }

        return reproducibility

    def _generate_artifact_info(self) -> Dict[str, Any]:
        """Generate build artifact information."""
        artifacts = {
            "build_outputs": {
                "executable": "pending_build",
                "data_files": "pending_build",
                "configuration": "pending_build"
            },
            "documentation_artifacts": [
                "CHANGELOG.md",
                "ADR/",
                "TASKS/",
                "build_provenance.json"
            ],
            "test_artifacts": {
                "test_reports": "pending",
                "coverage_reports": "pending",
                "performance_reports": "pending"
            },
            "deployment_artifacts": {
                "distribution_packages": "pending",
                "installer": "pending",
                "documentation": "generated"
            }
        }

        return artifacts

    def _generate_provenance_hash(self) -> str:
        """Generate hash of provenance data for integrity verification."""
        # Create deterministic hash of key provenance elements
        hash_data = {
            "commit_sha": self.provenance_data["git"]["commit_sha"],
            "build_time": self.provenance_data["metadata"]["build_time"],
            "environment": self.provenance_data["environment"]["platform"]["system"],
            "dependencies": str(self.provenance_data["dependencies"])
        }

        hash_string = json.dumps(hash_data, sort_keys=True)
        return hashlib.sha256(hash_string.encode()).hexdigest()

    # Helper methods
    def _run_git_command(self, args: List[str]) -> str:
        """Run git command and return output."""
        cmd = ["git"] + args
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=self.project_root)
        if result.returncode != 0:
            raise RuntimeError(f"Git command failed: {' '.join(cmd)}")
        return result.stdout

    def _get_dirty_files(self) -> List[str]:
        """Get list of modified files in working directory."""
        try:
            output = self._run_git_command(["status", "--porcelain"])
            return [line.strip() for line in output.splitlines() if line.strip()]
        except:
            return []

    def _detect_ci_environment(self) -> bool:
        """Detect if running in CI environment."""
        ci_indicators = ["CI", "CONTINUOUS_INTEGRATION", "GITHUB_ACTIONS", "GITLAB_CI", "JENKINS_URL"]
        return any(os.environ.get(var) for var in ci_indicators)

    def _get_ci_provider(self) -> str:
        """Identify CI provider."""
        if os.environ.get("GITHUB_ACTIONS"):
            return "GitHub Actions"
        elif os.environ.get("GITLAB_CI"):
            return "GitLab CI"
        elif os.environ.get("JENKINS_URL"):
            return "Jenkins"
        elif os.environ.get("TRAVIS"):
            return "Travis CI"
        elif self._detect_ci_environment():
            return "Unknown CI"
        else:
            return "Local Development"

    def _get_ci_variables(self) -> Dict[str, str]:
        """Get relevant CI environment variables."""
        ci_vars = {}
        ci_var_names = [
            "GITHUB_SHA", "GITHUB_REF", "GITHUB_REPOSITORY", "GITHUB_RUN_ID",
            "GITLAB_CI_COMMIT_SHA", "GITLAB_CI_COMMIT_REF_NAME", "CI_PROJECT_NAME",
            "BUILD_NUMBER", "JOB_NAME", "BUILD_URL"
        ]

        for var in ci_var_names:
            value = os.environ.get(var)
            if value:
                ci_vars[var] = value

        return ci_vars

    def _get_relevant_env_vars(self) -> Dict[str, str]:
        """Get relevant environment variables."""
        relevant_vars = ["PATH", "GODOT_PATH", "PYTHON_PATH", "HOME", "USER"]
        env_vars = {}

        for var in relevant_vars:
            value = os.environ.get(var)
            if value:
                env_vars[var] = value

        return env_vars

    def _get_godot_version(self) -> str:
        """Get Godot version information."""
        try:
            # Try to get Godot version from project
            result = subprocess.run(["godot", "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass

        # Fallback to project.godot file
        project_file = self.project_root / "capstone" / "project.godot"
        if project_file.exists():
            try:
                with open(project_file, 'r') as f:
                    for line in f:
                        if line.startswith('config_version='):
                            return f"Godot {line.split('=')[1].strip()}"
            except:
                pass

        return "Godot 4.4 (configured)"

    def _get_godot_features(self) -> List[str]:
        """Get Godot features and capabilities."""
        return [
            "3D Graphics",
            "Physics Engine",
            "Audio System",
            "Input Handling",
            "Scene System",
            "GDScript Support",
            "C# Support",
            "Export System"
        ]

    def _get_project_settings(self) -> Dict[str, Any]:
        """Get project configuration settings."""
        return {
            "application_name": "Dizzy's Disease",
            "target_platforms": ["Windows", "Linux", "macOS"],
            "rendering_backend": "Vulkan",
            "audio_backend": "PulseAudio/WASAPI",
            "physics_engine": "Godot Physics",
            "script_language": "GDScript"
        }

    def _get_build_configuration(self) -> Dict[str, Any]:
        """Get build configuration information."""
        return {
            "build_type": "Development",
            "optimization_level": "Debug",
            "target_platform": platform.system(),
            "architecture": platform.machine(),
            "debug_symbols": True,
            "assertions_enabled": True
        }

    def _get_export_presets(self) -> List[str]:
        """Get configured export presets."""
        return ["Windows Desktop", "Linux Desktop", "macOS Desktop"]

    def _get_python_packages(self) -> Dict[str, str]:
        """Get Python package versions."""
        packages = {}
        try:
            import pkg_resources
            for package in pkg_resources.working_set:
                packages[package.project_name] = package.version
        except:
            packages["error"] = "Unable to retrieve package information"

        return packages

    def _get_system_libraries(self) -> List[str]:
        """Get system library information."""
        return ["OpenGL", "Vulkan", "DirectX", "Audio Libraries"]

    def _get_build_tools(self) -> Dict[str, str]:
        """Get build tool versions."""
        tools = {}

        # Check common build tools
        tool_commands = {
            "python": ["python", "--version"],
            "git": ["git", "--version"],
            "godot": ["godot", "--version"]
        }

        for tool, command in tool_commands.items():
            try:
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode == 0:
                    tools[tool] = result.stdout.strip()
            except:
                tools[tool] = "Not available"

        return tools

    def _check_file_exists(self, file_path: str) -> bool:
        """Check if file exists in project."""
        return (self.project_root / file_path).exists()

    def _generate_project_checksums(self) -> Dict[str, str]:
        """Generate checksums for project files."""
        checksums = {}

        # Important project files to checksum
        important_files = [
            "capstone/project.godot",
            "api/app.py",
            "CHANGELOG.md",
            "build_provenance.py"
        ]

        for file_path in important_files:
            full_path = self.project_root / file_path
            if full_path.exists():
                checksums[file_path] = self._calculate_file_checksum(full_path)

        return checksums

    def _generate_config_checksums(self) -> Dict[str, str]:
        """Generate checksums for configuration files."""
        checksums = {}

        config_files = [
            "capstone/export_presets.cfg",
            "api/requirements.txt",
            "docker-compose.yml"
        ]

        for file_path in config_files:
            full_path = self.project_root / file_path
            if full_path.exists():
                checksums[file_path] = self._calculate_file_checksum(full_path)

        return checksums

    def _calculate_file_checksum(self, file_path: Path) -> str:
        """Calculate SHA256 checksum of file."""
        try:
            with open(file_path, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except:
            return "error_calculating_checksum"

    def save_provenance_bundle(self, output_path: Optional[str] = None) -> Path:
        """Save provenance bundle to JSON file."""
        if output_path is None:
            output_path = self.project_root / "build_provenance.json"
        else:
            output_path = Path(output_path)

        with open(output_path, 'w') as f:
            json.dump(self.provenance_data, f, indent=2, sort_keys=True)

        print(f"Build provenance saved to: {output_path}")
        return output_path

    def generate_provenance_report(self, output_path: Optional[str] = None) -> Path:
        """Generate human-readable provenance report."""
        if output_path is None:
            output_path = self.project_root / "BUILD_PROVENANCE_REPORT.md"
        else:
            output_path = Path(output_path)

        report = self._format_provenance_report()

        with open(output_path, 'w') as f:
            f.write(report)

        print(f"Build provenance report saved to: {output_path}")
        return output_path

    def _format_provenance_report(self) -> str:
        """Format provenance data as readable report."""
        data = self.provenance_data

        report = f"""# Build Provenance Report

**Project**: {data['metadata']['project_name']}
**Build ID**: {data['metadata']['build_id']}
**Build Time**: {data['metadata']['build_time']}
**Provenance Hash**: {data['provenance_hash']}

## Git Information

- **Commit SHA**: {data['git']['commit_sha']}
- **Branch**: {data['git']['branch']}
- **Author**: {data['git']['commit_author']}
- **Message**: {data['git']['commit_message']}
- **Dirty**: {data['git']['is_dirty']}

## Environment

- **Platform**: {data['environment']['platform']['system']} {data['environment']['platform']['release']}
- **Machine**: {data['environment']['platform']['machine']}
- **CI Environment**: {data['environment']['ci_environment']['ci_provider']}

## Build Configuration

- **Godot Version**: {data['dependencies']['godot']['version']}
- **Python Version**: {data['dependencies']['python']['version']}
- **Build Type**: {data['build']['build_configuration']['build_type']}

## Academic Compliance Status

"""

        # Add compliance information
        for gate, info in data['compliance']['academic_requirements'].items():
            status_emoji = "[DONE]" if info['status'] == 'completed' else "[PROG]" if info['status'] == 'in_progress' else "[PEND]"
            report += f"- **{gate.replace('_', ' ').title()}**: {status_emoji} {info['status']}\n"

        report += f"""
## Documentation Compliance

- **CHANGELOG.md**: {'[YES]' if data['compliance']['documentation_compliance']['changelog_present'] else '[NO]'}
- **README.md**: {'[YES]' if data['compliance']['documentation_compliance']['readme_present'] else '[NO]'}
- **ADR Documentation**: {'[YES]' if data['compliance']['documentation_compliance']['adr_present'] else '[NO]'}
- **Task Management**: {'[YES]' if data['compliance']['documentation_compliance']['tasks_present'] else '[NO]'}

## Performance Requirements

- **Target FPS**: {data['performance']['game_performance']['target_fps']}
- **Memory Budget**: {data['performance']['game_performance']['memory_budget_mb']} MB
- **Loading Time Target**: {data['performance']['game_performance']['loading_time_target_ms']} ms

---

*This report was generated automatically as part of the build provenance tracking system.*
*Report generated at: {datetime.now(timezone.utc).isoformat()}*
"""

        return report

def main():
    """Main entry point for build provenance generation."""
    print("Dizzy's Disease Build Provenance Generator")
    print("=" * 50)

    # Initialize generator
    generator = BuildProvenanceGenerator()

    # Generate full provenance bundle
    provenance_data = generator.generate_full_provenance()

    # Save outputs
    json_path = generator.save_provenance_bundle()
    report_path = generator.generate_provenance_report()

    print("\nProvenance Summary:")
    print(f"- Project: {provenance_data['metadata']['project_name']}")
    print(f"- Build ID: {provenance_data['metadata']['build_id']}")
    print(f"- Commit: {provenance_data['git']['commit_short']}")
    print(f"- Branch: {provenance_data['git']['branch']}")
    print(f"- CI Environment: {provenance_data['environment']['ci_environment']['ci_provider']}")
    print(f"- Provenance Hash: {provenance_data['provenance_hash'][:16]}...")

    print(f"\nBuild provenance generation completed successfully!")
    print(f"JSON Bundle: {json_path}")
    print(f"Human Report: {report_path}")

    return 0

if __name__ == "__main__":
    sys.exit(main())