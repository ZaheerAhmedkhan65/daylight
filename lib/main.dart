import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _background = Color(0xFFFAF9F6);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF302D34);
const _muted = Color(0xFF96929A);
const _line = Color(0xFFECE9E4);
const _purple = Color(0xFF7654D8);
const _lavender = Color(0xFFF0ECFB);

void main() {
  runApp(const PlannerApp());
}

enum TaskPriority { low, medium, high }

class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.title,
    required this.project,
    required this.dueAt,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.reminder = true,
    this.completed = false,
    this.subtasks = const [],
  });

  final String id;
  final String title;
  final String description;
  final String project;
  final DateTime dueAt;
  final TaskPriority priority;
  final bool reminder;
  final bool completed;
  final List<String> subtasks;

  PlannerTask copyWith({
    String? title,
    String? description,
    String? project,
    DateTime? dueAt,
    TaskPriority? priority,
    bool? reminder,
    bool? completed,
    List<String>? subtasks,
  }) {
    return PlannerTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      project: project ?? this.project,
      dueAt: dueAt ?? this.dueAt,
      priority: priority ?? this.priority,
      reminder: reminder ?? this.reminder,
      completed: completed ?? this.completed,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'project': project,
    'dueAt': dueAt.toIso8601String(),
    'priority': priority.name,
    'reminder': reminder,
    'completed': completed,
    'subtasks': subtasks,
  };

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      project: json['project'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      reminder: json['reminder'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      subtasks: List<String>.from(json['subtasks'] as List? ?? const []),
    );
  }
}

class PlannerProject {
  const PlannerProject({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color tint;
}

const _projects = [
  PlannerProject(
    name: 'Studio',
    subtitle: 'Make good things',
    icon: Icons.palette_outlined,
    color: Color(0xFF8A69D6),
    tint: Color(0xFFF1ECFA),
  ),
  PlannerProject(
    name: 'Personal',
    subtitle: 'Life, lately',
    icon: Icons.home_outlined,
    color: Color(0xFF739477),
    tint: Color(0xFFEDF3EC),
  ),
  PlannerProject(
    name: 'Wellbeing',
    subtitle: 'Take it gently',
    icon: Icons.spa_outlined,
    color: Color(0xFFCC9568),
    tint: Color(0xFFFAF0E7),
  ),
  PlannerProject(
    name: 'Learning',
    subtitle: 'Stay curious',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF6D96B1),
    tint: Color(0xFFEDF3F7),
  ),
];

class PlannerApp extends StatefulWidget {
  const PlannerApp({super.key});

  @override
  State<PlannerApp> createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> {
  static const _storageKey = 'daylight_planner_tasks_v1';
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  List<PlannerTask> _tasks = [];
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  int _tabIndex = 0;
  String? _selectedProject;
  bool _isLoading = true;
  String? _loadError;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedTasks = preferences.getString(_storageKey);
      if (savedTasks == null) {
        _tasks = _starterTasks(DateUtils.dateOnly(DateTime.now()));
      } else {
        final decoded = jsonDecode(savedTasks) as List<dynamic>;
        _tasks = decoded
            .map((item) => PlannerTask.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'Could not load your tasks. Please try again.';
        });
      }
    }
  }

  Future<void> _saveTasks() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      if (!mounted) return;
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Your changes could not be saved.')),
      );
    }
  }

  Future<void> _openEditor({PlannerTask? task, String? project}) async {
    final result = await _navigatorKey.currentState!.push<PlannerTask>(
      MaterialPageRoute(
        builder: (_) => TaskEditorPage(
          projects: _projects,
          initialTask: task,
          initialDate: _selectedDate,
          initialProject: project ?? _selectedProject,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      final index = _tasks.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _tasks.add(result);
      } else {
        _tasks[index] = result;
      }
      _selectedDate = DateUtils.dateOnly(result.dueAt);
    });
    await _saveTasks();
  }

  Future<void> _toggleTask(PlannerTask task) async {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index != -1) {
        _tasks[index] = task.copyWith(completed: !task.completed);
      }
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(PlannerTask task) async {
    final confirmed = await showDialog<bool>(
      context: _navigatorKey.currentState!.overlay!.context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep task'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _saveTasks();
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      if (index != 0) _selectedProject = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Daylight',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _purple,
          surface: _background,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              color: selected ? _purple : _muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            );
          }),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: _isLoading
          ? const _LoadingScreen()
          : _loadError != null
          ? _LoadErrorScreen(onRetry: _loadTasks)
          : Scaffold(
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: _tabIndex,
                        children: [
                          _TodayScreen(
                            tasks: _tasks,
                            selectedDate: _selectedDate,
                            selectedProject: _selectedProject,
                            showCompleted: _showCompleted,
                            onToggleCompleted: () => setState(
                              () => _showCompleted = !_showCompleted,
                            ),
                            onAdd: () => _openEditor(),
                            onEdit: (task) => _openEditor(task: task),
                            onToggle: _toggleTask,
                            onDelete: _deleteTask,
                            onClearProject: () =>
                                setState(() => _selectedProject = null),
                          ),
                          _UpcomingScreen(
                            tasks: _tasks,
                            selectedDate: _selectedDate,
                            onSelectDate: (date) => setState(
                              () => _selectedDate = DateUtils.dateOnly(date),
                            ),
                            onAdd: () => _openEditor(),
                            onEdit: (task) => _openEditor(task: task),
                            onToggle: _toggleTask,
                            onDelete: _deleteTask,
                          ),
                          _ProjectsScreen(
                            tasks: _tasks,
                            onSelectProject: (project) => setState(() {
                              _selectedProject = project;
                              _tabIndex = 0;
                            }),
                            onAddTask: (project) =>
                                _openEditor(project: project),
                          ),
                        ],
                      ),
                    ),
                    NavigationBar(
                      height: 72,
                      backgroundColor: _background,
                      indicatorColor: const Color(0xFFE5DEFA),
                      selectedIndex: _tabIndex,
                      onDestinationSelected: _selectTab,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.check_circle_outline, color: _muted),
                          selectedIcon: Icon(
                            Icons.check_circle,
                            color: _purple,
                          ),
                          label: 'Today',
                        ),
                        NavigationDestination(
                          icon: Icon(
                            Icons.calendar_month_outlined,
                            color: _muted,
                          ),
                          selectedIcon: Icon(
                            Icons.calendar_month,
                            color: _purple,
                          ),
                          label: 'Upcoming',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined, color: _muted),
                          selectedIcon: Icon(Icons.dashboard, color: _purple),
                          label: 'Projects',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<PlannerTask> _starterTasks(DateTime today) {
    DateTime at(int dayOffset, int hour, int minute) =>
        DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

    return [
      PlannerTask(
        id: 'starter-review',
        title: 'Review homepage concepts',
        project: 'Studio',
        dueAt: at(0, 9, 30),
        priority: TaskPriority.high,
      ),
      PlannerTask(
        id: 'starter-reading',
        title: 'Read 20 pages',
        project: 'Personal',
        dueAt: at(0, 12, 0),
        priority: TaskPriority.low,
      ),
      PlannerTask(
        id: 'starter-groceries',
        title: 'Pick up groceries',
        project: 'Personal',
        dueAt: at(0, 15, 0),
      ),
      PlannerTask(
        id: 'starter-stretch',
        title: 'Evening stretch',
        project: 'Wellbeing',
        dueAt: at(0, 19, 30),
        priority: TaskPriority.low,
      ),
      PlannerTask(
        id: 'starter-notes',
        title: 'Write morning pages',
        project: 'Personal',
        dueAt: at(0, 8, 0),
        priority: TaskPriority.low,
        completed: true,
      ),
      PlannerTask(
        id: 'starter-plan',
        title: 'Plan the week',
        project: 'Studio',
        dueAt: at(0, 8, 30),
        completed: true,
      ),
      PlannerTask(
        id: 'starter-presentation',
        title: 'Prepare client presentation',
        project: 'Studio',
        dueAt: at(1, 10, 0),
        priority: TaskPriority.high,
      ),
      PlannerTask(
        id: 'starter-walk',
        title: 'Take a long walk',
        project: 'Wellbeing',
        dueAt: at(2, 17, 0),
        priority: TaskPriority.low,
      ),
    ];
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: _purple)),
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40, color: _muted),
              const SizedBox(height: 16),
              const Text(
                'Your planner could not be opened.',
                style: TextStyle(color: _ink, fontSize: 17),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayScreen extends StatelessWidget {
  const _TodayScreen({
    required this.tasks,
    required this.selectedDate,
    required this.selectedProject,
    required this.showCompleted,
    required this.onToggleCompleted,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onClearProject,
  });

  final List<PlannerTask> tasks;
  final DateTime selectedDate;
  final String? selectedProject;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;
  final VoidCallback onAdd;
  final ValueChanged<PlannerTask> onEdit;
  final ValueChanged<PlannerTask> onToggle;
  final ValueChanged<PlannerTask> onDelete;
  final VoidCallback onClearProject;

  @override
  Widget build(BuildContext context) {
    final todayTasks =
        tasks
            .where(
              (task) =>
                  DateUtils.isSameDay(task.dueAt, selectedDate) &&
                  (selectedProject == null || task.project == selectedProject),
            )
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final openTasks = todayTasks.where((task) => !task.completed).toList();
    final completedTasks = todayTasks.where((task) => task.completed).toList();
    final completeCount = tasks.where((task) => task.completed).length;
    final percent = tasks.isEmpty
        ? 0
        : (completeCount * 100 / tasks.length).round();

    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        children: [
          _PageHeader(
            eyebrow: _dateEyebrow(selectedDate),
            title: selectedProject ?? 'Today',
            action: _AddButton(onPressed: onAdd),
          ),
          if (selectedProject != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.close, size: 16),
                label: Text('Showing $selectedProject'),
                onPressed: onClearProject,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _ProgressCard(
            completed: completeCount,
            total: tasks.length,
            percent: percent,
            title: selectedProject == null
                ? 'Small steps, big days.'
                : 'A little progress adds up.',
            subtitle: selectedProject == null
                ? 'You’re on right track. One task at a time.'
                : 'Keep showing up for ${selectedProject!.toLowerCase()}.',
          ),
          const SizedBox(height: 25),
          _SectionHeading(
            title: 'Your tasks',
            count: openTasks.length,
            trailing: 'By time',
          ),
          const SizedBox(height: 9),
          if (openTasks.isEmpty)
            const _EmptyTasksMessage(
              title: 'A little breathing room.',
              subtitle: 'Add a task whenever you’re ready.',
            )
          else
            ...openTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TaskCard(
                  task: task,
                  onTap: () => onEdit(task),
                  onToggle: () => onToggle(task),
                  onEdit: () => onEdit(task),
                  onDelete: () => onDelete(task),
                ),
              ),
            ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onToggleCompleted,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 17, color: _muted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${completedTasks.length} ${completedTasks.length == 1 ? 'task' : 'tasks'}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    showCompleted
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _muted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
          if (showCompleted)
            ...completedTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TaskCard(
                  task: task,
                  onTap: () => onEdit(task),
                  onToggle: () => onToggle(task),
                  onEdit: () => onEdit(task),
                  onDelete: () => onDelete(task),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingScreen extends StatelessWidget {
  const _UpcomingScreen({
    required this.tasks,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<PlannerTask> tasks;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onAdd;
  final ValueChanged<PlannerTask> onEdit;
  final ValueChanged<PlannerTask> onToggle;
  final ValueChanged<PlannerTask> onDelete;

  void _moveMonth(int offset) {
    final targetMonth = DateTime(
      selectedDate.year,
      selectedDate.month + offset,
      1,
    );
    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    onSelectDate(
      DateTime(
        targetMonth.year,
        targetMonth.month,
        selectedDate.day.clamp(1, lastDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks =
        tasks
            .where((task) => DateUtils.isSameDay(task.dueAt, selectedDate))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - DateTime.monday),
    );

    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          _PageHeader(
            eyebrow: 'MAKE ROOM FOR WHAT’S NEXT',
            title: 'Upcoming',
            action: _AddButton(onPressed: onAdd),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthName(selectedDate.month)} ${selectedDate.year}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                color: _muted,
                tooltip: 'Previous month',
              ),
              IconButton(
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                color: _muted,
                tooltip: 'Next month',
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final isSelected = DateUtils.isSameDay(date, selectedDate);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? _purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayShort(date.weekday),
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : _muted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? _purple
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: _dateHeading(selectedDate),
            count: dayTasks.length,
            trailing: 'tasks',
          ),
          const SizedBox(height: 14),
          if (dayTasks.isEmpty)
            const _EmptyTasksMessage(
              title: 'Nothing on the calendar.',
              subtitle: 'Enjoy the open space or add something new.',
            )
          else
            ...dayTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _TimelineTask(
                  task: task,
                  onTap: () => onEdit(task),
                  onToggle: () => onToggle(task),
                  onEdit: () => onEdit(task),
                  onDelete: () => onDelete(task),
                ),
              ),
            ),
          const SizedBox(height: 14),
          _TomorrowCard(
            onTap: () => onSelectDate(
              DateUtils.dateOnly(selectedDate.add(const Duration(days: 1))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectsScreen extends StatefulWidget {
  const _ProjectsScreen({
    required this.tasks,
    required this.onSelectProject,
    required this.onAddTask,
  });

  final List<PlannerTask> tasks;
  final ValueChanged<String> onSelectProject;
  final ValueChanged<String> onAddTask;

  @override
  State<_ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<_ProjectsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingProjects = _projects
        .where(
          (project) =>
              project.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final completedCount = widget.tasks.where((task) => task.completed).length;
    final progress = widget.tasks.isEmpty
        ? 0
        : (completedCount * 100 / widget.tasks.length).round();

    return _PageFrame(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          _PageHeader(
            eyebrow: 'A LITTLE SPACE FOR EVERY PART OF YOU',
            title: 'Projects',
            action: _AddButton(onPressed: () => widget.onAddTask('Studio')),
          ),
          const SizedBox(height: 21),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search your projects',
              hintStyle: const TextStyle(color: _muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 19, color: _muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              filled: true,
              fillColor: const Color(0xFFF1F0EC),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Your spaces',
            count: matchingProjects.length,
            trailing: 'projects',
          ),
          const SizedBox(height: 12),
          if (matchingProjects.isEmpty)
            const _EmptyTasksMessage(
              title: 'No spaces found.',
              subtitle: 'Try a different search.',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matchingProjects.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.12,
              ),
              itemBuilder: (context, index) {
                final project = matchingProjects[index];
                final projectTasks = widget.tasks
                    .where((task) => task.project == project.name)
                    .toList();
                final done = projectTasks
                    .where((task) => task.completed)
                    .length;
                final double percent = projectTasks.isEmpty
                    ? 0
                    : done * 100 / projectTasks.length;
                return _ProjectCard(
                  project: project,
                  taskCount: projectTasks.length,
                  progress: percent,
                  onTap: () => widget.onSelectProject(project.name),
                  onAdd: () => widget.onAddTask(project.name),
                );
              },
            ),
          const SizedBox(height: 18),
          _WeekWinsCard(completed: completedCount, percent: progress),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.taskCount,
    required this.progress,
    required this.onTap,
    required this.onAdd,
  });

  final PlannerProject project;
  final int taskCount;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: project.tint,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(project.icon, size: 16, color: project.color),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onAdd,
                    tooltip: 'Add task to ${project.name}',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz, size: 18, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                project.name,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$taskCount ${taskCount == 1 ? 'task' : 'tasks'} · ${project.subtitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 4,
                  color: project.color,
                  backgroundColor: project.tint,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${progress.round()}% complete',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        action,
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: 'Create task',
      style: IconButton.styleFrom(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        fixedSize: const Size(42, 42),
      ),
      icon: const Icon(Icons.add, size: 21),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.percent,
    required this.title,
    required this.subtitle,
  });

  final int completed;
  final int total;
  final int percent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(
        color: _lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completed / total,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.8),
              color: _purple,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed of $total tasks completed',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    required this.trailing,
  });

  final String title;
  final int count;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EFEB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        Text(trailing, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.showTime = true,
  });

  final PlannerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final project = _projectFor(task.project);
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 5, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onToggle,
                tooltip: task.completed ? 'Mark incomplete' : 'Mark complete',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  task.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 21,
                  color: task.completed ? _purple : const Color(0xFFD8D5D0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: task.completed ? _muted : _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (showTime) ...[
                          Text(
                            _formatTime(task.dueAt),
                            style: const TextStyle(color: _muted, fontSize: 9),
                          ),
                          const SizedBox(width: 7),
                        ],
                        _ProjectTag(project: project),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                tooltip: 'Task actions',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_horiz, size: 18, color: _muted),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit task')),
                  PopupMenuItem(value: 'delete', child: Text('Delete task')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTask extends StatelessWidget {
  const _TimelineTask({
    required this.task,
    required this.onTap,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 57,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _formatTime(task.dueAt),
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
        ),
        SizedBox(
          width: 18,
          height: 64,
          child: Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 17),
                decoration: BoxDecoration(
                  color: _projectFor(task.project).color,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: Container(width: 1, color: _line)),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TaskCard(
              task: task,
              onTap: onTap,
              onToggle: onToggle,
              onEdit: onEdit,
              onDelete: onDelete,
              showTime: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectTag extends StatelessWidget {
  const _ProjectTag({required this.project});

  final PlannerProject project;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: project.tint,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        project.name,
        style: TextStyle(
          color: project.color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyTasksMessage extends StatelessWidget {
  const _EmptyTasksMessage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TomorrowCard extends StatelessWidget {
  const _TomorrowCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return Material(
      color: const Color(0xFFF1F0EC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: _muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Tomorrow · ${_monthName(tomorrow.month)} ${tomorrow.day}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekWinsCard extends StatelessWidget {
  const _WeekWinsCard({required this.completed, required this.percent});

  final int completed;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _lavender,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, color: _purple, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A week of little wins',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completed tasks done so far · $percent% of your plan',
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, color: _purple, size: 19),
        ],
      ),
    );
  }
}

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    required this.projects,
    required this.initialDate,
    this.initialProject,
    this.initialTask,
    super.key,
  });

  final List<PlannerProject> projects;
  final DateTime initialDate;
  final String? initialProject;
  final PlannerTask? initialTask;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subtaskController;
  late DateTime _dueAt;
  late String _project;
  late TaskPriority _priority;
  late bool _reminder;
  late List<String> _subtasks;
  String? _titleError;
  bool _hasSubtaskText = false;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _subtaskController = TextEditingController();
    _dueAt =
        task?.dueAt ??
        _withTime(widget.initialDate, const TimeOfDay(hour: 10, minute: 0));
    _project =
        task?.project ?? widget.initialProject ?? widget.projects.first.name;
    _priority = task?.priority ?? TaskPriority.high;
    _reminder = task?.reminder ?? true;
    _subtasks = List.of(task?.subtasks ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final value = _subtaskController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _subtasks.add(value);
      _subtaskController.clear();
      _hasSubtaskText = false;
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your task a name to get started.');
      return;
    }
    final existing = widget.initialTask;
    Navigator.of(context).pop(
      PlannerTask(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        description: _descriptionController.text.trim(),
        project: _project,
        dueAt: _dueAt,
        priority: _priority,
        reminder: _reminder,
        completed: existing?.completed ?? false,
        subtasks: List.of(_subtasks),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _purple)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        _dueAt.hour,
        _dueAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;
    setState(() => _dueAt = _withTime(_dueAt, time));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ONE SMALL STEP FORWARD',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEditing ? 'Edit task' : 'New task',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: _muted, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0EFEB),
                      fixedSize: const Size(34, 34),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(21, 14, 21, 20),
                children: [
                  const _FieldLabel('TASK NAME'),
                  const SizedBox(height: 7),
                  TextField(
                    key: const Key('task-title'),
                    controller: _titleController,
                    minLines: 2,
                    maxLines: 3,
                    autofocus: false,
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'What would you like to do?',
                      hintStyle: const TextStyle(color: Color(0xFFB7B3BB)),
                      errorText: _titleError,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    ),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a little more detail...',
                      hintStyle: const TextStyle(color: _muted, fontSize: 12),
                      filled: true,
                      fillColor: _surface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: _ink, fontSize: 12),
                  ),
                  const SizedBox(height: 17),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _EditorOption(
                          icon: Icons.folder_open_outlined,
                          title: 'Project',
                          value: _project,
                          valueColor: _projectFor(_project).color,
                          valueMarkerColor: _projectFor(_project).color,
                          onTap: _pickProject,
                        ),
                        _EditorOption(
                          icon: Icons.calendar_today_outlined,
                          title: 'Due date',
                          value: _formatFullDate(_dueAt),
                          valueColor: _ink,
                          onTap: _pickDate,
                        ),
                        _EditorOption(
                          icon: Icons.access_time,
                          title: 'Time',
                          value: _formatTime(_dueAt),
                          valueColor: _ink,
                          onTap: _pickTime,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  const _FieldLabel('PRIORITY'),
                  const SizedBox(height: 8),
                  Row(
                    children: TaskPriority.values.map((priority) {
                      final selected = _priority == priority;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: OutlinedButton(
                            onPressed: () =>
                                setState(() => _priority = priority),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: selected ? _purple : _muted,
                              backgroundColor: selected ? _lavender : _surface,
                              side: BorderSide(
                                color: selected ? _purple : _line,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _capitalize(priority.name),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _reminder,
                    onChanged: (value) => setState(() => _reminder = value),
                    activeTrackColor: _purple,
                    title: const Text(
                      'Remind me',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'A gentle nudge when it’s time',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                    secondary: const Icon(
                      Icons.notifications_none,
                      size: 19,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Subtasks',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _subtasks.isEmpty ? 'Optional' : '${_subtasks.length}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                  for (var index = 0; index < _subtasks.length; index++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.radio_button_unchecked,
                        size: 17,
                        color: _muted,
                      ),
                      title: Text(
                        _subtasks[index],
                        style: const TextStyle(color: _ink, fontSize: 12),
                      ),
                      trailing: IconButton(
                        onPressed: () =>
                            setState(() => _subtasks.removeAt(index)),
                        tooltip: 'Remove subtask',
                        icon: const Icon(Icons.close, size: 16, color: _muted),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('subtask-input'),
                          controller: _subtaskController,
                          onChanged: (value) => setState(
                            () => _hasSubtaskText = value.trim().isNotEmpty,
                          ),
                          onSubmitted: (_) => _addSubtask(),
                          decoration: const InputDecoration(
                            hintText: 'Add a subtask',
                            hintStyle: TextStyle(color: _muted, fontSize: 11),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(color: _ink, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        key: const Key('add-subtask'),
                        onPressed: _hasSubtaskText ? _addSubtask : null,
                        tooltip: 'Add subtask',
                        icon: const Icon(Icons.add, size: 19),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 9, 20, 14),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 19),
                  label: Text(
                    _isEditing ? 'Save changes' : 'Create task',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProject() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _background,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a project',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ...widget.projects.map(
                (project) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: project.tint,
                    child: Icon(project.icon, color: project.color, size: 19),
                  ),
                  title: Text(
                    project.name,
                    style: const TextStyle(color: _ink, fontSize: 13),
                  ),
                  trailing: _project == project.name
                      ? const Icon(Icons.check, color: _purple, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, project.name),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _project = selected);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 9,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EditorOption extends StatelessWidget {
  const _EditorOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.valueColor,
    this.valueMarkerColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color valueColor;
  final Color? valueMarkerColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: _line))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: _ink, fontSize: 12),
              ),
            ),
            if (valueMarkerColor != null) ...[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: valueMarkerColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 17, color: _muted),
          ],
        ),
      ),
    );
  }
}

PlannerProject _projectFor(String name) => _projects.firstWhere(
  (project) => project.name == name,
  orElse: () => _projects.first,
);

DateTime _withTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _dateEyebrow(DateTime date) =>
    '${_weekdayLong(date.weekday).toUpperCase()}, ${_monthName(date.month).toUpperCase()} ${date.day}';

String _dateHeading(DateTime date) {
  if (DateUtils.isSameDay(date, DateTime.now())) {
    return 'Today, ${_monthName(date.month)} ${date.day}';
  }
  return '${_weekdayLong(date.weekday)}, ${_monthName(date.month)} ${date.day}';
}

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _weekdayLong(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][weekday - 1];

String _weekdayShort(int weekday) =>
    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _formatFullDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';

String _capitalize(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';
