import 'package:flutter/material.dart';

class ResponsiveLayout extends StatefulWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;

  const ResponsiveLayout({
    super.key,
    required this.body,
    required this.title,
    this.actions,
  });

  @override
  State<ResponsiveLayout> createState() => _ResponsiveLayoutState();
}

class _ResponsiveLayoutState extends State<ResponsiveLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 900;
        final bool isTablet =
            constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        if (isDesktop || isTablet) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  extended: isDesktop,
                  labelType: isDesktop
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Icon(Icons.rocket_launch, size: 32),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Clients'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: Colors.white.withAlpha(25),
                ),
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(widget.title),
                      actions: widget.actions,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                    ),
                    body: widget.body,
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile Layout
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: widget.actions,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: widget.body,
          drawer: Drawer(
            child: ListView(
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Color(0xFF1E1E1E)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Deploy GUI',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Clients'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
