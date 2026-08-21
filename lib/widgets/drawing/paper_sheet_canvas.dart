import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import '../../models/drawing_stroke.dart';
import '../../theme/app_theme.dart';

class ClinicalPenColor {
  final String name;
  final Color color;
  final String hex;

  const ClinicalPenColor(this.name, this.color, this.hex);
}

class PaperSheetCanvas extends StatefulWidget {
  final List<VectorStroke> initialStrokes;
  final ValueChanged<List<VectorStroke>> onStrokesChanged;
  final VoidCallback? onSave;
  final VoidCallback? onPrint;
  final String? patientName;
  final String? middleName;
  final String? date;
  final String? ageSex;
  final String? address;
  final String? contactNumber;
  final String? occupation;
  final String? phicNumber;
  final String? birthDate;

  const PaperSheetCanvas({
    super.key,
    this.initialStrokes = const [],
    required this.onStrokesChanged,
    this.onSave,
    this.onPrint,
    this.patientName,
    this.middleName,
    this.date,
    this.ageSex,
    this.address,
    this.contactNumber,
    this.occupation,
    this.phicNumber,
    this.birthDate,
  });

  @override
  State<PaperSheetCanvas> createState() => _PaperSheetCanvasState();
}

class _PaperSheetCanvasState extends State<PaperSheetCanvas> {
  static const List<ClinicalPenColor> penColors = [
    ClinicalPenColor('Medical Black', Color(0xFF0F172A), '#0F172A'),
    ClinicalPenColor('Clinical Blue', Color(0xFF1D4ED8), '#1D4ED8'),
    ClinicalPenColor('Retinal Red', Color(0xFFDC2626), '#DC2626'),
    ClinicalPenColor('Drusen Yellow', Color(0xFFEAB308), '#EAB308'),
    ClinicalPenColor('Fluorescein Green', Color(0xFF16A34A), '#16A34A'),
    ClinicalPenColor('Lesion Orange', Color(0xFFD97706), '#D97706'),
  ];

  static const List<ClinicalPenColor> highlighterColors = [
    ClinicalPenColor('Neon Yellow', Color(0xFFFACC15), '#FACC15'),
    ClinicalPenColor('Neon Green', Color(0xFF4ADE80), '#4ADE80'),
    ClinicalPenColor('Neon Pink', Color(0xFFF472B6), '#F472B6'),
    ClinicalPenColor('Neon Orange', Color(0xFFFB923C), '#FB923C'),
    ClinicalPenColor('Neon Sky Blue', Color(0xFF38BDF8), '#38BDF8'),
    ClinicalPenColor('Neon Purple', Color(0xFFC084FC), '#C084FC'),
  ];

  DrawingTool _activeTool = DrawingTool.pen;
  Color _selectedColor = const Color(0xFF0F172A);
  Color _selectedHighlighterColor = const Color(0xFFFACC15);
  double _selectedSize = 1.7;

  List<VectorStroke> _strokes = [];
  final List<VectorStroke> _redoStack = [];
  List<Offset> _currentPoints = [];
  final GlobalKey _canvasKey = GlobalKey();

  bool _showColorTray = false;
  bool _showHighlighterColorTray = false;
  bool _showSizeTray = false;
  bool _savedIndicator = false;

  @override
  void initState() {
    super.initState();
    _strokes = List.from(widget.initialStrokes);
  }

  @override
  void didUpdateWidget(covariant PaperSheetCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStrokes != widget.initialStrokes) {
      setState(() {
        _strokes = List.from(widget.initialStrokes);
      });
    }
  }

  void _triggerChange() {
    widget.onStrokesChanged(_strokes);
    setState(() {
      _savedIndicator = true;
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _savedIndicator = false);
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    setState(() {
      _showColorTray = false;
      _showHighlighterColorTray = false;
      _showSizeTray = false;

      if (_activeTool == DrawingTool.eraser) {
        _eraseStrokesAt(localPos, 16.0);
      } else {
        _currentPoints = [localPos];
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);

    setState(() {
      if (_activeTool == DrawingTool.eraser) {
        _eraseStrokesAt(localPos, 16.0);
      } else {
        if (_currentPoints.isNotEmpty) {
          final last = _currentPoints.last;
          // Filter micro-jitter duplicates (< 0.5px)
          if ((localPos - last).distance < 0.5) return;
          _currentPoints.add(localPos);
        } else {
          _currentPoints.add(localPos);
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_activeTool != DrawingTool.eraser && _currentPoints.isNotEmpty) {
      final newStroke = VectorStroke(
        id: 'stk-${DateTime.now().millisecondsSinceEpoch}',
        tool: _activeTool,
        color: _activeTool == DrawingTool.highlighter
            ? _selectedHighlighterColor.withValues(alpha: 0.35)
            : _selectedColor,
        size: _activeTool == DrawingTool.highlighter ? 16.0 : _selectedSize,
        points: List.from(_currentPoints),
      );

      setState(() {
        _strokes.add(newStroke);
        _redoStack.clear();
        _currentPoints = [];
      });
      _triggerChange();
    } else {
      setState(() {
        _currentPoints = [];
      });
    }
  }

  void _eraseStrokesAt(Offset pos, double radius) {
    bool erasedAny = false;
    _strokes.removeWhere((stroke) {
      for (final p in stroke.points) {
        if ((p - pos).distance <= radius + (stroke.size / 2)) {
          erasedAny = true;
          return true;
        }
      }
      return false;
    });

    if (erasedAny) {
      _triggerChange();
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes.removeLast());
      });
      _triggerChange();
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStack.removeLast());
      });
      _triggerChange();
    }
  }

  void _clearInk() {
    if (_strokes.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Clear All Ink Drawings?'),
        content: const Text('This will erase all handwritten annotations from the paper consultation record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _strokes.clear();
                _redoStack.clear();
              });
              _triggerChange();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Erase All'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE2E8F0),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 1. SCROLLABLE CLINICAL PAPER CHART RECORD
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 24, bottom: 100, left: 16, right: 16),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, outerConstraints) {
                    // Standard Paper Record Dimension (Aspect ratio matching clinical paper chart: 8.5 x 11 in)
                    final double sheetWidth = math.min(900.0, math.max(680.0, outerConstraints.maxWidth - 32));
                    final double sheetHeight = sheetWidth * 1.32; // Standard clinical paper aspect ratio

                    return Container(
                      width: sheetWidth,
                      height: sheetHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            // LAYER 1: 100% Vector Recreated Physical Clinical Paper Form
                            CustomPaint(
                              size: Size(sheetWidth, sheetHeight),
                              painter: PrintedPaperSheetPainter(
                                width: sheetWidth,
                                height: sheetHeight,
                                patientName: widget.patientName,
                                middleName: widget.middleName,
                                date: widget.date,
                                ageSex: widget.ageSex,
                                address: widget.address,
                                contactNumber: widget.contactNumber,
                                occupation: widget.occupation,
                                phicNumber: widget.phicNumber,
                                birthDate: widget.birthDate,
                              ),
                            ),

                            // LAYER 2: Tablet Vector Inking Surface (Smooth stylus / touch gesture capture)
                            Positioned.fill(
                              child: GestureDetector(
                                key: _canvasKey,
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                onPanEnd: _onPanEnd,
                                child: CustomPaint(
                                  size: Size(sheetWidth, sheetHeight),
                                  painter: PaperSheetInkingPainter(
                                    strokes: _strokes,
                                    currentPoints: _currentPoints,
                                    currentColor: _activeTool == DrawingTool.highlighter
                                        ? _selectedHighlighterColor.withValues(alpha: 0.35)
                                        : _selectedColor,
                                    currentSize: _activeTool == DrawingTool.highlighter ? 16.0 : _selectedSize,
                                    currentTool: _activeTool,
                                  ),
                                ),
                              ),
                            ),

                            // Floating Save Indicator Badge
                            if (_savedIndicator)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text('Ink Saved', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 2. FIXED FLOATING TABLET PEN TOOLBAR & POPUPS (Always docked on screen directly above the bottom)
          Positioned(
            bottom: 20,
            child: _buildTabletFloatingToolbar(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FLOATING TABLET PEN TOOLBAR (MODERN WHITE)
  // ==========================================
  Widget _buildTabletFloatingToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Expandable Palette Trays (Positioned above the bar)
        if (_showColorTray) _buildColorTray(),
        if (_showHighlighterColorTray) _buildHighlighterColorTray(),
        if (_showSizeTray) _buildSizeTray(),
        if (_showColorTray || _showHighlighterColorTray || _showSizeTray) const SizedBox(height: 10),

        // Main White Modern Toolbar Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🖊️ Pen Tool (With Active Highlight & Color Dot)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _activeTool = DrawingTool.pen;
                      _showColorTray = !_showColorTray;
                      _showHighlighterColorTray = false;
                      _showSizeTray = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _activeTool == DrawingTool.pen ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeTool == DrawingTool.pen ? AppTheme.primaryBlue : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          color: _activeTool == DrawingTool.pen ? AppTheme.primaryBlue : const Color(0xFF475569),
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        // Active Pen Color Dot Indicator
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: _selectedColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 📏 Stroke Size Selector (With Active Highlight)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _showSizeTray = !_showSizeTray;
                      _showColorTray = false;
                      _showHighlighterColorTray = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _showSizeTray ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showSizeTray ? AppTheme.primaryBlue : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.line_weight,
                      color: _showSizeTray ? AppTheme.primaryBlue : const Color(0xFF475569),
                      size: 19,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 🖍️ Highlighter Tool (Marker Icon with Active Highlight & Color Dot)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _activeTool = DrawingTool.highlighter;
                      _showHighlighterColorTray = !_showHighlighterColorTray;
                      _showColorTray = false;
                      _showSizeTray = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _activeTool == DrawingTool.highlighter ? const Color(0xFFFEF3C7) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeTool == DrawingTool.highlighter ? const Color(0xFFF59E0B) : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.border_color,
                          color: _activeTool == DrawingTool.highlighter ? const Color(0xFFD97706) : const Color(0xFF475569),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        // Active Highlighter Color Dot Indicator
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _selectedHighlighterColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: _selectedHighlighterColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // 🧹 Eraser Tool (Cleaning Eraser Icon with Active Highlight)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _activeTool = DrawingTool.eraser;
                      _showColorTray = false;
                      _showHighlighterColorTray = false;
                      _showSizeTray = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _activeTool == DrawingTool.eraser ? const Color(0xFFFFE4E6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _activeTool == DrawingTool.eraser ? Colors.redAccent : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      color: _activeTool == DrawingTool.eraser ? Colors.redAccent : const Color(0xFF475569),
                      size: 19,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),
              Container(width: 1.2, height: 22, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 6),

              // ↩️ Undo
              IconButton(
                onPressed: _strokes.isEmpty ? null : _undo,
                icon: Icon(
                  Icons.undo,
                  color: _strokes.isNotEmpty ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  size: 19,
                ),
                tooltip: 'Undo Stroke',
                visualDensity: VisualDensity.compact,
              ),

              // ↪️ Redo
              IconButton(
                onPressed: _redoStack.isEmpty ? null : _redo,
                icon: Icon(
                  Icons.redo,
                  color: _redoStack.isNotEmpty ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  size: 19,
                ),
                tooltip: 'Redo Stroke',
                visualDensity: VisualDensity.compact,
              ),

              // 🗑️ Clear
              IconButton(
                onPressed: _strokes.isEmpty ? null : _clearInk,
                icon: Icon(
                  Icons.delete_outline,
                  color: _strokes.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
                  size: 19,
                ),
                tooltip: 'Clear All Ink',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorTray() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        children: penColors.map((item) {
          final isSelected = _selectedColor == item.color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = item.color;
                _showColorTray = false;
              });
            },
            child: Tooltip(
              message: item.name,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBlue : Colors.black12,
                    width: isSelected ? 3.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHighlighterColorTray() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        children: highlighterColors.map((item) {
          final isSelected = _selectedHighlighterColor == item.color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedHighlighterColor = item.color;
                _showHighlighterColorTray = false;
              });
            },
            child: Tooltip(
              message: item.name,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF59E0B) : Colors.black12,
                    width: isSelected ? 3.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSizeTray() {
    final previewColor = _activeTool == DrawingTool.highlighter ? _selectedHighlighterColor : _selectedColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Dynamic Circle Size Preview Floating Outside Above the Pop-up Box
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 20),
            width: (_selectedSize * 3.6).clamp(3.0, 40.0),
            height: (_selectedSize * 3.6).clamp(3.0, 40.0),
            decoration: BoxDecoration(
              color: previewColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: previewColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // 2. White Modern Pop-up Box (Contains ONLY the slider)
        Container(
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryBlue,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: AppTheme.primaryBlue,
              overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _selectedSize,
              min: 1.0,
              max: 10.0,
              onChanged: (val) {
                setState(() {
                  _selectedSize = val;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// 100% FAITHFUL VECTOR RECREATION OF THE PHYSICAL CONSULTATION PAPER SHEET
// =========================================================================
class PrintedPaperSheetPainter extends CustomPainter {
  final double width;
  final double height;
  final String? patientName;
  final String? middleName;
  final String? date;
  final String? ageSex;
  final String? address;
  final String? contactNumber;
  final String? occupation;
  final String? phicNumber;
  final String? birthDate;

  PrintedPaperSheetPainter({
    required this.width,
    required this.height,
    this.patientName,
    this.middleName,
    this.date,
    this.ageSex,
    this.address,
    this.contactNumber,
    this.occupation,
    this.phicNumber,
    this.birthDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = width / 820.0;
    final scaleY = height / 1080.0;

    Offset pt(double x, double y) => Offset(x * scaleX, y * scaleY);
    Rect rct(double l, double t, double w, double h) => Rect.fromLTWH(l * scaleX, t * scaleY, w * scaleX, h * scaleY);

    // 1. Paper Background (Crisp clinical off-white with fine medical border)
    final bgPaint = Paint()..color = const Color(0xFFFCFDFE);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scaleX;

    final linePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scaleX;

    final thinLinePaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scaleX;

    void drawText(String text, double x, double y, {double fontSize = 11, bool isBold = true, Color color = const Color(0xFF0F172A)}) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize * scaleX,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          fontFamily: 'sans-serif',
          letterSpacing: 0.2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, pt(x, y));
    }

    // Helper to draw aligned text inside a cell box (center, top, bottom)
    void drawCellText(String text, double left, double top, double width, double height, {
      double fontSize = 10.5,
      bool isBold = true,
      Color color = const Color(0xFF0F172A),
      double lineHeight = 1.15,
      Alignment alignment = Alignment.center,
    }) {
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize * scaleX,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          fontFamily: 'sans-serif',
          letterSpacing: 0.2,
          height: lineHeight,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double textX = (left * scaleX) + (((width * scaleX) - textPainter.width) / 2);
      if (alignment == Alignment.topLeft || alignment == Alignment.centerLeft || alignment == Alignment.bottomLeft) {
        textX = (left + 3.0) * scaleX;
      } else if (alignment == Alignment.topRight || alignment == Alignment.centerRight || alignment == Alignment.bottomRight) {
        textX = (left * scaleX) + (width * scaleX) - textPainter.width - (3.0 * scaleX);
      }

      double textY = (top * scaleY) + (((height * scaleY) - textPainter.height) / 2);
      if (alignment == Alignment.topCenter || alignment == Alignment.topLeft || alignment == Alignment.topRight) {
        textY = (top + 2.5) * scaleY;
      } else if (alignment == Alignment.bottomCenter || alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) {
        textY = (top * scaleY) + (height * scaleY) - textPainter.height - (2.5 * scaleY);
      }

      textPainter.paint(canvas, Offset(textX, textY));
    }

    // ==========================================
    // SECTION A: HEADER DEMOGRAPHICS (TOP & BOTTOM ALIGNED RECTANGLE)
    // ==========================================
    // Top Row: Left Name: & Middle Name: align horizontally with Right Date: (y = 42, line = 54)
    drawText('Name:', 20, 42, fontSize: 11.0);
    canvas.drawLine(pt(68, 54), pt(405, 54), linePaint);
    if (patientName != null && patientName!.isNotEmpty) {
      drawText(patientName!, 74, 40, fontSize: 11.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    drawText('Middle Name:', 418, 42, fontSize: 11.0);
    canvas.drawLine(pt(508, 54), pt(625, 54), linePaint);
    if (middleName != null && middleName!.isNotEmpty) {
      drawText(middleName!, 514, 40, fontSize: 11.0, isBold: true, color: const Color(0xFF1E3A8A));
    }

    drawText('Date:', 640, 42, fontSize: 11.0);
    canvas.drawLine(pt(710, 54), pt(795, 54), linePaint);
    if (date != null && date!.isNotEmpty) {
      drawText(date!, 714, 40, fontSize: 11.0, isBold: true, color: const Color(0xFF1E3A8A));
    }

    // Right Column Intermediate Row 2 (y = 68, line = 80)
    drawText('Age/Sex:', 640, 68, fontSize: 11.0);
    canvas.drawLine(pt(710, 80), pt(795, 80), linePaint);
    if (ageSex != null && ageSex!.isNotEmpty) {
      drawText(ageSex!, 714, 66, fontSize: 11.0, isBold: true, color: const Color(0xFF1E3A8A));
    }

    // Left Column Middle Row 2: Address: adjusted evenly between top and bottom (y = 81, line = 93)
    drawText('Address:', 20, 81, fontSize: 11.0);
    canvas.drawLine(pt(80, 93), pt(625, 93), linePaint);
    if (address != null && address!.isNotEmpty) {
      drawText(address!, 86, 79, fontSize: 10.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    // Right Column Intermediate Row 3 (y = 94, line = 106)
    drawText('Contact #:', 640, 94, fontSize: 11.0);
    canvas.drawLine(pt(710, 106), pt(795, 106), linePaint);
    if (contactNumber != null && contactNumber!.isNotEmpty) {
      drawText(contactNumber!, 714, 92, fontSize: 10.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    // Bottom Row: Left Occupation: & PHIC #: align horizontally with Right Birth Date: (y = 120, line = 132)
    drawText('Occupation:', 20, 120, fontSize: 11.0);
    canvas.drawLine(pt(98, 132), pt(405, 132), linePaint);
    if (occupation != null && occupation!.isNotEmpty) {
      drawText(occupation!, 104, 118, fontSize: 10.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    drawText('PHIC #:', 418, 120, fontSize: 11.0);
    canvas.drawLine(pt(478, 132), pt(625, 132), linePaint);
    if (phicNumber != null && phicNumber!.isNotEmpty) {
      drawText(phicNumber!, 484, 118, fontSize: 10.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    drawText('Birth Date:', 640, 120, fontSize: 11.0);
    canvas.drawLine(pt(710, 132), pt(795, 132), linePaint);
    if (birthDate != null && birthDate!.isNotEmpty) {
      drawText(birthDate!, 714, 118, fontSize: 10.5, isBold: true, color: const Color(0xFF1E3A8A));
    }

    // ==========================================
    // SECTION B: TABLE 1 - REFRACTION & VA GRID (MERGED LABEL CELLS & CENTERED)
    // ==========================================
    // Outer Table border spanning full width across the sheet from x = 20 to x = 795
    final table1Rect = rct(20, 142, 775, 56);
    canvas.drawRect(table1Rect, borderPaint);

    // Horizontal Row dividers ONLY in the value boxes and OD/OS column (NO lines through CC, Old CC, AR, AK)
    canvas.drawLine(pt(20, 170), pt(54, 170), linePaint);   // OD / OS divider
    canvas.drawLine(pt(86, 170), pt(140, 170), linePaint);  // VA / PH value box divider
    canvas.drawLine(pt(176, 170), pt(230, 170), linePaint); // CC value box divider
    canvas.drawLine(pt(274, 170), pt(374, 170), linePaint); // Old CC value box divider
    canvas.drawLine(pt(408, 170), pt(580, 170), linePaint); // AR wide value box divider
    canvas.drawLine(pt(614, 170), pt(795, 170), linePaint); // AK wide value box divider

    // Vertical Column dividers
    canvas.drawLine(pt(54, 142), pt(54, 198), linePaint);   // OD/OS
    canvas.drawLine(pt(86, 142), pt(86, 198), linePaint);   // VA/PH
    canvas.drawLine(pt(140, 142), pt(140, 198), linePaint); // VA/PH values
    canvas.drawLine(pt(176, 142), pt(176, 198), linePaint); // CC (Merged full height)
    canvas.drawLine(pt(230, 142), pt(230, 198), linePaint); // CC values
    canvas.drawLine(pt(274, 142), pt(274, 198), linePaint); // Old CC (Merged full height)
    canvas.drawLine(pt(374, 142), pt(374, 198), linePaint); // Old CC values
    canvas.drawLine(pt(408, 142), pt(408, 198), linePaint); // AR (Merged full height)
    canvas.drawLine(pt(580, 142), pt(580, 198), linePaint); // AR wide values
    canvas.drawLine(pt(614, 142), pt(614, 198), linePaint); // AK (Merged full height)

    // Table 1 Printed Labels (All perfectly centered horizontally & vertically)
    drawCellText('OD', 20, 142, 34, 28, fontSize: 10.5);
    drawCellText('OS', 20, 170, 34, 28, fontSize: 10.5);

    drawCellText('VA', 54, 142, 32, 28, fontSize: 10.5);
    drawCellText('PH', 54, 170, 32, 28, fontSize: 10.5);

    drawCellText('CC', 140, 142, 36, 56, fontSize: 10.5);

    drawCellText('Old\nCC', 230, 142, 44, 56, fontSize: 10.0);

    drawCellText('AR', 374, 142, 34, 56, fontSize: 10.5);
    drawCellText('AK', 580, 142, 34, 56, fontSize: 10.5);

    // ==========================================
    // SECTION C: TABLE 2 - CLINICAL EXAM MATRIX (CENTER ALIGNED & POSITIONED)
    // ==========================================
    final table2Rect = rct(20, 208, 605, 80);
    canvas.drawRect(table2Rect, borderPaint);

    // Horizontal Row Dividers
    canvas.drawLine(pt(20, 234), pt(625, 234), linePaint); // Header bottom
    canvas.drawLine(pt(20, 261), pt(625, 261), linePaint); // OD bottom

    // Column Dividers
    canvas.drawLine(pt(54, 208), pt(54, 288), linePaint);   // OD/OS
    canvas.drawLine(pt(98, 208), pt(98, 288), linePaint);   // Color
    canvas.drawLine(pt(140, 208), pt(140, 288), linePaint); // IOP
    canvas.drawLine(pt(260, 208), pt(260, 288), linePaint); // Angles Gonioscopy
    canvas.drawLine(pt(345, 208), pt(345, 288), linePaint); // CDR / ON
    canvas.drawLine(pt(495, 208), pt(495, 288), linePaint); // Confrontation / Peripheral

    // Table 2 Header Labels (Centered in each column header box)
    drawCellText('Color', 54, 208, 44, 26, fontSize: 10.0);
    drawCellText('IOP', 98, 208, 42, 26, fontSize: 10.0);
    drawCellText('Angles Gonioscopy', 140, 208, 120, 26, fontSize: 10.0);
    drawCellText('CDR / ON', 260, 208, 85, 26, fontSize: 10.0);
    drawCellText('Confrontation / Peripheral', 345, 208, 150, 26, fontSize: 10.0);
    drawCellText('Van Herick', 495, 208, 130, 26, fontSize: 10.0);

    // OD Row
    drawCellText('OD', 20, 234, 34, 27, fontSize: 10.5);
    drawCellText('B', 54, 234, 44, 13.5, fontSize: 9.0);
    drawCellText('G', 54, 247.5, 44, 13.5, fontSize: 9.0);

    // Centered Open / Narrow / Closed in Angles Gonioscopy
    drawCellText('Open\nNarrow\nClosed', 140, 234, 62, 27, fontSize: 8.0, isBold: false, lineHeight: 1.05);
    // Gonioscopy circle target OD (Centered in the remaining half)
    canvas.drawCircle(pt(228, 247.5), 10.0 * scaleX, thinLinePaint);

    // CDR / ON circle OD (Dead-center of the CDR cell)
    canvas.drawCircle(pt(302.5, 247.5), 10.5 * scaleX, thinLinePaint);

    // Centered WNL / Defect in Confrontation / Peripheral
    drawCellText('WNL\nDefect', 345, 234, 65, 27, fontSize: 8.5, isBold: false, lineHeight: 1.15);
    // Upper circle of visual field map (Centered in the remaining half)
    canvas.drawCircle(pt(450, 247.5), 10.5 * scaleX, thinLinePaint);

    // Van Herick OD (Top-aligned in cell)
    drawCellText('G1 G2 G3 G4 Wide', 495, 234, 130, 27, fontSize: 9.0, isBold: false, alignment: Alignment.topCenter);

    // OS Row
    drawCellText('OS', 20, 261, 34, 27, fontSize: 10.5);
    drawCellText('B', 54, 261, 44, 13.5, fontSize: 9.0);
    drawCellText('G', 54, 274.5, 44, 13.5, fontSize: 9.0);

    // Centered Open / Narrow / Closed in Angles Gonioscopy
    drawCellText('Open\nNarrow\nClosed', 140, 261, 62, 27, fontSize: 8.0, isBold: false, lineHeight: 1.05);
    // Gonioscopy circle target OS
    canvas.drawCircle(pt(228, 274.5), 10.0 * scaleX, thinLinePaint);

    // CDR / ON circle OS
    canvas.drawCircle(pt(302.5, 274.5), 10.5 * scaleX, thinLinePaint);

    // Centered WNL / Defect in Confrontation / Peripheral
    drawCellText('WNL\nDefect', 345, 261, 65, 27, fontSize: 8.5, isBold: false, lineHeight: 1.15);
    // Lower circle of visual field map
    canvas.drawCircle(pt(450, 274.5), 10.5 * scaleX, thinLinePaint);

    // Van Herick OS (Top-aligned in cell)
    drawCellText('G1 G2 G3 G4 Wide', 495, 261, 130, 27, fontSize: 9.0, isBold: false, alignment: Alignment.topCenter);

    // ==========================================
    // SECTION D: RIGHT COLUMN - SYSTEMIC HISTORY (WITH OTHERS & UNIFORM SPACING)
    // ==========================================
    const historyEntries = [
      'Cardiac Problem',
      'DM',
      'HPN',
      'Kidney Problem',
      'Cholesterol det',
      'Allergy Hx',
      'Asthma Hx',
      'Thyroid Problem',
      'Others:',
    ];

    const double historyStartY = 206.0;
    const double historyPitch = 18.5;

    for (int i = 0; i < historyEntries.length; i++) {
      final double hy = historyStartY + (i * historyPitch);
      final String label = historyEntries[i];

      // Draw real vector square checkbox
      final checkboxRect = RRect.fromRectAndRadius(
        rct(640, hy - 1, 11, 11),
        Radius.circular(2.0 * scaleX),
      );
      canvas.drawRRect(checkboxRect, thinLinePaint);

      // Draw label next to checkbox
      drawText(label, 658, hy, fontSize: 10.0);

      // If 'Others:', draw blank underline for doctor to write
      if (label == 'Others:') {
        canvas.drawLine(pt(704, hy + 10), pt(795, hy + 10), linePaint);
      }
    }

    // ==========================================
    // SECTION E: PRINTED EYE ANATOMICAL TEMPLATES (1:1 PHYSICAL PHOTO MATCH)
    // ==========================================
    // 1. Anterior Cornea / Slit Lamp Templates
    // Helper to build authentic hollow crescent bracket with flat end caps
    Path buildCrescentBracket(Offset center, double innerR, double outerR) {
      final path = Path();
      const double angleSpan = math.pi * 0.40; // ~72 degrees

      final outerRect = Rect.fromCircle(center: center, radius: outerR);
      path.addArc(outerRect, math.pi - angleSpan, angleSpan * 2);

      final innerRect = Rect.fromCircle(center: center, radius: innerR);
      path.arcTo(innerRect, math.pi + angleSpan, -angleSpan * 2, false);

      path.close();
      return path;
    }

    // OD Cornea (OD label to left of bracket + circle)
    drawText('OD', 575, 418, fontSize: 11.0);
    final odBracketCenter = pt(633, 426);
    final double odInnerR = 19.0 * scaleX;
    final double odOuterR = 25.5 * scaleX;
    final odBracket = buildCrescentBracket(odBracketCenter, odInnerR, odOuterR);
    canvas.drawPath(odBracket, borderPaint);
    final odCircleCenter = pt(643, 426);
    canvas.drawCircle(odCircleCenter, 17.0 * scaleX, borderPaint);

    // OS Cornea (OS label to left of bracket + circle)
    drawText('OS', 685, 418, fontSize: 11.0);
    final osBracketCenter = pt(743, 426);
    final double osInnerR = 19.0 * scaleX;
    final double osOuterR = 25.5 * scaleX;
    final osBracket = buildCrescentBracket(osBracketCenter, osInnerR, osOuterR);
    canvas.drawPath(osBracket, borderPaint);
    final osCircleCenter = pt(753, 426);
    canvas.drawCircle(osCircleCenter, 17.0 * scaleX, borderPaint);

    // 2. Dilated Fundus Exam Templates
    drawText('Dilated Fundus Exam', 580, 485, fontSize: 11.0);

    // Helper to draw authentic Dilated Fundus diagram with nasal disc & vessel arcades
    void drawFundusDiagram(Offset center, double radius, bool isOD) {
      // Outer Fundus Circle
      canvas.drawCircle(center, radius, borderPaint);

      // Optic Disc (Small circle on nasal side: right for OD, left for OS)
      final double discOffsetX = isOD ? radius * 0.44 : -radius * 0.44;
      final discCenter = Offset(center.dx + discOffsetX, center.dy);
      final double discRadius = radius * 0.18;
      canvas.drawCircle(discCenter, discRadius, borderPaint);

      // Nasal anchor curves from optic disc to the outer circle border
      final nasalTop = Path();
      nasalTop.moveTo(discCenter.dx, discCenter.dy - discRadius);
      nasalTop.quadraticBezierTo(
        isOD ? center.dx + radius * 0.72 : center.dx - radius * 0.72,
        center.dy - radius * 0.12,
        isOD ? center.dx + radius * 0.98 : center.dx - radius * 0.98,
        center.dy - radius * 0.18,
      );
      canvas.drawPath(nasalTop, borderPaint);

      final nasalBot = Path();
      nasalBot.moveTo(discCenter.dx, discCenter.dy + discRadius);
      nasalBot.quadraticBezierTo(
        isOD ? center.dx + radius * 0.72 : center.dx - radius * 0.72,
        center.dy + radius * 0.12,
        isOD ? center.dx + radius * 0.98 : center.dx - radius * 0.98,
        center.dy + radius * 0.18,
      );
      canvas.drawPath(nasalBot, borderPaint);

      // Superior Vessel Arcade (arches up and across toward temporal side)
      final supArcade = Path();
      supArcade.moveTo(isOD ? discCenter.dx - discRadius * 0.2 : discCenter.dx + discRadius * 0.2, discCenter.dy - discRadius * 0.85);
      supArcade.cubicTo(
        isOD ? center.dx + radius * 0.05 : center.dx - radius * 0.05,
        center.dy - radius * 0.86,
        isOD ? center.dx - radius * 0.42 : center.dx + radius * 0.42,
        center.dy - radius * 0.72,
        isOD ? center.dx - radius * 0.65 : center.dx + radius * 0.65,
        center.dy - radius * 0.45,
      );
      canvas.drawPath(supArcade, borderPaint);

      // Inferior Vessel Arcade (arches down and across toward temporal side)
      final infArcade = Path();
      infArcade.moveTo(isOD ? discCenter.dx - discRadius * 0.2 : discCenter.dx + discRadius * 0.2, discCenter.dy + discRadius * 0.85);
      infArcade.cubicTo(
        isOD ? center.dx + radius * 0.05 : center.dx - radius * 0.05,
        center.dy + radius * 0.86,
        isOD ? center.dx - radius * 0.42 : center.dx + radius * 0.42,
        center.dy + radius * 0.72,
        isOD ? center.dx - radius * 0.65 : center.dx + radius * 0.65,
        center.dy + radius * 0.45,
      );
      canvas.drawPath(infArcade, borderPaint);
    }

    const double fundusRadius = 35.0;
    // OD Fundus
    drawText('OD', 575, 542, fontSize: 11.0);
    final odFundusCenter = pt(636, 550);
    drawFundusDiagram(odFundusCenter, fundusRadius * scaleX, true);

    // OS Fundus
    drawText('OS', 685, 542, fontSize: 11.0);
    final osFundusCenter = pt(746, 550);
    drawFundusDiagram(osFundusCenter, fundusRadius * scaleX, false);

    // ==========================================
    // SECTION F: CLINICAL NOTES & WRITING LINES (GENEROUS SPACING, NO OVERLAP)
    // ==========================================
    drawText('Chief Complaint / HPI', 20, 312, fontSize: 11.0);

    drawText('Assessment:', 20, 680, fontSize: 11.0);

    drawText('Plan:', 20, 740, fontSize: 11.0);
  }

  @override
  bool shouldRepaint(covariant PrintedPaperSheetPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.height != height ||
        oldDelegate.patientName != patientName ||
        oldDelegate.middleName != middleName ||
        oldDelegate.date != date ||
        oldDelegate.ageSex != ageSex ||
        oldDelegate.address != address ||
        oldDelegate.contactNumber != contactNumber ||
        oldDelegate.occupation != occupation ||
        oldDelegate.phicNumber != phicNumber ||
        oldDelegate.birthDate != birthDate;
  }
}

// =========================================================================
// HIGH PERFORMANCE VECTOR INKING PAINTER (PERFECT FREEHAND + SPLINE SUBDIVISION)
// =========================================================================
List<Offset> _subdividePoints(List<Offset> rawPoints, {double maxDistance = 5.0}) {
  if (rawPoints.length < 3) return rawPoints;

  final result = <Offset>[rawPoints.first];
  for (int i = 0; i < rawPoints.length - 1; i++) {
    final p0 = i > 0 ? rawPoints[i - 1] : rawPoints[i];
    final p1 = rawPoints[i];
    final p2 = rawPoints[i + 1];
    final p3 = (i + 2 < rawPoints.length) ? rawPoints[i + 2] : p2;

    final dist = (p2 - p1).distance;
    if (dist > maxDistance) {
      final segments = (dist / maxDistance).ceil().clamp(2, 8);
      for (int s = 1; s < segments; s++) {
        final t = s / segments;
        final t2 = t * t;
        final t3 = t2 * t;

        final x = 0.5 * (
          (2 * p1.dx) +
          (-p0.dx + p2.dx) * t +
          (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
          (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3
        );
        final y = 0.5 * (
          (2 * p1.dy) +
          (-p0.dy + p2.dy) * t +
          (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
          (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3
        );
        result.add(Offset(x, y));
      }
    }
    result.add(p2);
  }
  return result;
}

class PaperSheetInkingPainter extends CustomPainter {
  final List<VectorStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentSize;
  final DrawingTool currentTool;

  PaperSheetInkingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentSize,
    required this.currentTool,
  });

  Path _getStrokePath(List<Offset> rawPoints, double size, bool isHighlighter) {
    if (rawPoints.isEmpty) return Path();
    if (rawPoints.length == 1) {
      final path = Path();
      path.addOval(Rect.fromCircle(
          center: rawPoints.first, radius: size / 2));
      return path;
    }

    final points = _subdividePoints(rawPoints);

    // Dynamic stroke options with balanced speed-responsive thinning
    final strokeOptions = StrokeOptions(
      size: isHighlighter ? size * 2.0 : size,
      thinning: isHighlighter ? 0.0 : 0.22, // Subtle, natural ink weight variation without over-pinching
      smoothing: 0.80,
      streamline: 0.55,
      simulatePressure: true,
      isComplete: true,
    );

    final outlinePoints = getStroke(
      points.map((p) => PointVector(p.dx, p.dy)).toList(),
      options: strokeOptions,
    );

    final path = Path();
    if (outlinePoints.isEmpty) return path;

    if (outlinePoints.length < 3) {
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 1; i < outlinePoints.length; i++) {
        path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
      }
      path.close();
      return path;
    }

    // Midpoint quadratic bezier curves for continuous C1 smooth contours with zero facet artifacts
    final first = outlinePoints[0];
    final second = outlinePoints[1];
    path.moveTo((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);

    for (int i = 1; i < outlinePoints.length; i++) {
      final current = outlinePoints[i];
      final next = outlinePoints[(i + 1) % outlinePoints.length];
      final midX = (current.dx + next.dx) / 2;
      final midY = (current.dy + next.dy) / 2;
      path.quadraticBezierTo(current.dx, current.dy, midX, midY);
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Render all completed vector strokes
    for (final s in strokes) {
      if (s.points.isEmpty) continue;

      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      if (s.tool == DrawingTool.highlighter) {
        paint.blendMode = BlendMode.multiply;
      }

      final path = _getStrokePath(s.points, s.size, s.tool == DrawingTool.highlighter);
      canvas.drawPath(path, paint);
    }

    // 2. Render active in-progress pen stroke
    if (currentPoints.isNotEmpty && currentTool != DrawingTool.eraser) {
      final activePaint = Paint()
        ..color = currentColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      if (currentTool == DrawingTool.highlighter) {
        activePaint.blendMode = BlendMode.multiply;
      }

      final activePath = _getStrokePath(currentPoints, currentSize, currentTool == DrawingTool.highlighter);
      canvas.drawPath(activePath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant PaperSheetInkingPainter oldDelegate) {
    return true;
  }
}

