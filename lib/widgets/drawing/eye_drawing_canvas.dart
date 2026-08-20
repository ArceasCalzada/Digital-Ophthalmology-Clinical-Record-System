import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/drawing_stroke.dart';
import '../../models/eye_exam.dart';
import '../../theme/app_theme.dart';

class OphthalmicColor {
  final String name;
  final Color color;

  const OphthalmicColor(this.name, this.color);
}

class EyeDrawingCanvas extends StatefulWidget {
  final EyeType eye;
  final ValueChanged<EyeType> onEyeChanged;
  final EyeDrawingData? drawingData;
  final EyeDrawingData? priorDrawingData;
  final ValueChanged<EyeDrawingData> onDrawingSaved;
  final String diagramType; // 'fundus', 'anterior', or 'plain'

  const EyeDrawingCanvas({
    super.key,
    required this.eye,
    required this.onEyeChanged,
    this.drawingData,
    this.priorDrawingData,
    required this.onDrawingSaved,
    this.diagramType = 'fundus',
  });

  @override
  State<EyeDrawingCanvas> createState() => _EyeDrawingCanvasState();
}

class _EyeDrawingCanvasState extends State<EyeDrawingCanvas> {
  static const List<OphthalmicColor> ophthalmicColors = [
    OphthalmicColor('Retinal Red', Color(0xFFDC2626)),
    OphthalmicColor('Vein Blue', Color(0xFF2563EB)),
    OphthalmicColor('Drusen Yellow', Color(0xFFEAB308)),
    OphthalmicColor('Fluorescein Green', Color(0xFF10B981)),
    OphthalmicColor('Lesion Orange', Color(0xFFD97706)),
    OphthalmicColor('White Opacity', Color(0xFFFFFFFF)),
    OphthalmicColor('Black Marking', Color(0xFF000000)),
  ];

  static const List<Map<String, String>> presetSymbols = [
    {'id': 'cataract', 'label': 'Cataract Opacity', 'color': '0xFF2563EB'},
    {'id': 'retinal_tear', 'label': 'Retinal Tear', 'color': '0xFFDC2626'},
    {'id': 'flame_hem', 'label': 'Flame Hemorrhage', 'color': '0xFFDC2626'},
    {'id': 'drusen', 'label': 'Drusen Lesion', 'color': '0xFFEAB308'},
    {'id': 'pterygium', 'label': 'Pterygium Wing', 'color': '0xFF10B981'},
    {'id': 'glaucoma_notch', 'label': 'Optic Notch', 'color': '0xFFD97706'},
  ];

  DrawingTool _activeTool = DrawingTool.pen;
  Color _selectedColor = const Color(0xFFDC2626);
  final double _brushSize = 3.0;
  String _selectedSymbol = 'cataract';

  bool _showColorDrawer = false;
  bool _showStampDrawer = false;

  final bool _showGhostOverlay = true;
  final double _ghostOpacity = 0.35;
  final double _cdRatio = 0.50;

  List<VectorStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  bool _showSavedIndicator = false;

  @override
  void initState() {
    super.initState();
    if (widget.drawingData != null) {
      _strokes = List.from(widget.drawingData!.strokes);
    }
  }

  @override
  void didUpdateWidget(covariant EyeDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eye != widget.eye || oldWidget.drawingData != widget.drawingData) {
      setState(() {
        if (widget.drawingData != null) {
          _strokes = List.from(widget.drawingData!.strokes);
        } else {
          _strokes = [];
        }
      });
    }
  }

  void _triggerAutoSave() {
    final updatedData = EyeDrawingData(
      id: widget.drawingData?.id ?? 'drw-${DateTime.now().millisecondsSinceEpoch}',
      encounterId: widget.drawingData?.encounterId ?? 'enc-active',
      patientId: widget.drawingData?.patientId ?? 'pat-active',
      eye: widget.eye,
      diagramType: widget.diagramType,
      strokes: _strokes,
      cdRatio: _cdRatio,
      updatedAt: DateTime.now().toIso8601String(),
    );

    widget.onDrawingSaved(updatedData);

    setState(() {
      _showSavedIndicator = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showSavedIndicator = false;
        });
      }
    });
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    if (_activeTool == DrawingTool.symbol) {
      final symbolStroke = VectorStroke(
        id: 's-${DateTime.now().millisecondsSinceEpoch}',
        tool: DrawingTool.symbol,
        color: _selectedColor,
        size: _brushSize,
        points: [localPosition],
        symbolType: _selectedSymbol,
      );
      setState(() {
        _strokes.add(symbolStroke);
        _showStampDrawer = false;
      });
      _triggerAutoSave();
      return;
    }

    setState(() {
      _currentPoints = [localPosition];
      _showColorDrawer = false;
      _showStampDrawer = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_activeTool == DrawingTool.symbol) return;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    setState(() {
      _currentPoints.add(localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints.isNotEmpty && _activeTool != DrawingTool.symbol) {
      final newStroke = VectorStroke(
        id: 's-${DateTime.now().millisecondsSinceEpoch}',
        tool: _activeTool == DrawingTool.eraser ? DrawingTool.eraser : DrawingTool.pen,
        color: _selectedColor,
        size: _brushSize,
        points: List.from(_currentPoints),
      );

      setState(() {
        _strokes.add(newStroke);
        _currentPoints = [];
      });
      _triggerAutoSave();
    }
  }

  void _undoLastStroke() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      _triggerAutoSave();
    }
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _currentPoints.clear();
    });
    _triggerAutoSave();
  }

  void _openFullScreenDrawingDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(
                'Full-Screen Eye Drawing Canvas — ${widget.eye == EyeType.OD ? "Right Eye (OD)" : "Left Eye (OS)"}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              actions: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text('Done & Return', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: EyeDrawingCanvas(
                eye: widget.eye,
                onEyeChanged: widget.onEyeChanged,
                diagramType: widget.diagramType,
                drawingData: widget.drawingData,
                priorDrawingData: widget.priorDrawingData,
                onDrawingSaved: (data) {
                  widget.onDrawingSaved(data);
                  setState(() {
                    _strokes = List.from(data.strokes);
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Target Eye: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(width: 6),
                  SegmentedButton<EyeType>(
                    segments: const [
                      ButtonSegment(value: EyeType.OD, label: Text('OD')),
                      ButtonSegment(value: EyeType.OS, label: Text('OS')),
                    ],
                    selected: {widget.eye},
                    onSelectionChanged: (Set<EyeType> selection) {
                      widget.onEyeChanged(selection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppTheme.primaryBlue,
                      selectedForegroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),

              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_showSavedIndicator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Saved', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      widget.diagramType == 'fundus'
                          ? 'Fundus'
                          : widget.diagramType == 'anterior'
                              ? 'Anterior'
                              : 'Plain',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: AppTheme.primaryBlue, size: 20),
                    tooltip: 'Open Full-Screen Drawing Canvas',
                    onPressed: _openFullScreenDrawingDialog,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Main Canvas Frame + Canva-Style Floating Toolbar Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Base Canvas Area
                  _buildCanvasFrame(constraints),

                  // Floating Canva-Style Toolbar at Bottom
                  Positioned(
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Floating Expandable Color/Stamp Drawer Tray
                        if (_showColorDrawer) _buildFloatingColorTray(),
                        if (_showStampDrawer) _buildFloatingStampTray(),
                        if (_showColorDrawer || _showStampDrawer) const SizedBox(height: 8),

                        // Canva Floating Bottom Toolbar Pill
                        _buildCanvaFloatingToolbar(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCanvaFloatingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            spreadRadius: 2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pen Tool Button
          IconButton(
            onPressed: () {
              setState(() {
                _activeTool = DrawingTool.pen;
                _showColorDrawer = !_showColorDrawer;
                _showStampDrawer = false;
              });
            },
            icon: Icon(
              Icons.edit,
              color: _activeTool == DrawingTool.pen ? Colors.white : Colors.white54,
              size: 20,
            ),
            tooltip: 'Pen Tool & Colors',
          ),

          // Selected Color Circle Indicator
          GestureDetector(
            onTap: () {
              setState(() {
                _activeTool = DrawingTool.pen;
                _showColorDrawer = !_showColorDrawer;
                _showStampDrawer = false;
              });
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: _selectedColor.withValues(alpha: 0.6), blurRadius: 6),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),

          // Clinical Stamps / Presets Button
          IconButton(
            onPressed: () {
              setState(() {
                _activeTool = DrawingTool.symbol;
                _showStampDrawer = !_showStampDrawer;
                _showColorDrawer = false;
              });
            },
            icon: Icon(
              Icons.category,
              color: _activeTool == DrawingTool.symbol ? AppTheme.accentCyan : Colors.white54,
              size: 20,
            ),
            tooltip: 'Clinical Stamps',
          ),

          // Eraser Tool Button
          IconButton(
            onPressed: () {
              setState(() {
                _activeTool = DrawingTool.eraser;
                _showColorDrawer = false;
                _showStampDrawer = false;
              });
            },
            icon: Icon(
              Icons.cleaning_services,
              color: _activeTool == DrawingTool.eraser ? Colors.amber : Colors.white54,
              size: 20,
            ),
            tooltip: 'Eraser Tool',
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: 8),

          // Undo Button
          IconButton(
            onPressed: _strokes.isEmpty ? null : _undoLastStroke,
            icon: Icon(
              Icons.undo,
              color: _strokes.isNotEmpty ? Colors.white : Colors.white24,
              size: 20,
            ),
            tooltip: 'Undo Stroke',
          ),

          // Clear Button
          IconButton(
            onPressed: _strokes.isEmpty ? null : _clearCanvas,
            icon: Icon(
              Icons.delete_outline,
              color: _strokes.isNotEmpty ? Colors.redAccent : Colors.white24,
              size: 20,
            ),
            tooltip: 'Clear Canvas',
          ),

          const SizedBox(width: 4),
          // Full Screen Expand Icon
          IconButton(
            onPressed: _openFullScreenDrawingDialog,
            icon: const Icon(
              Icons.fullscreen,
              color: AppTheme.primaryBlue,
              size: 22,
            ),
            tooltip: 'Full Screen Canvas',
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingColorTray() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: ophthalmicColors.map((item) {
          final isSelected = _selectedColor == item.color;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = item.color;
                _showColorDrawer = false;
              });
            },
            child: Tooltip(
              message: item.name,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white30,
                    width: isSelected ? 3.0 : 1.0,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingStampTray() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.6)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT CLINICAL STAMP', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presetSymbols.map((sym) {
              final isSelected = _selectedSymbol == sym['id'];
              final symColor = Color(int.parse(sym['color']!));
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedSymbol = sym['id']!;
                    _selectedColor = symColor;
                    _showStampDrawer = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryBlue : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.white : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: symColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(sym['label']!, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasFrame(BoxConstraints outerConstraints) {
    final double maxAvailWidth = outerConstraints.maxWidth.isFinite ? outerConstraints.maxWidth : 340.0;
    final double canvasDimension = math.min(360.0, math.max(280.0, maxAvailWidth - 12));
    final isPlain = widget.diagramType == 'plain';

    return Center(
      child: Container(
        width: canvasDimension,
        height: canvasDimension,
        decoration: BoxDecoration(
          color: isPlain ? Colors.white : Colors.black,
          shape: isPlain ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isPlain ? BorderRadius.circular(16) : null,
          border: Border.all(
            color: isPlain ? AppTheme.primaryBlue : AppTheme.accentCyan,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPlain ? AppTheme.primaryBlue : AppTheme.accentCyan).withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: isPlain ? BorderRadius.circular(13) : BorderRadius.circular(180),
          child: GestureDetector(
            onPanStart: (d) => _onPanStart(d, Size(canvasDimension, canvasDimension)),
            onPanUpdate: (d) => _onPanUpdate(d, Size(canvasDimension, canvasDimension)),
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              size: Size(canvasDimension, canvasDimension),
              painter: AnatomicalEyePainter(
                eye: widget.eye,
                diagramType: widget.diagramType,
                cdRatio: _cdRatio,
                strokes: _strokes,
                currentPoints: _currentPoints,
                currentColor: _selectedColor,
                currentBrushSize: _brushSize,
                currentTool: _activeTool,
                priorStrokes: _showGhostOverlay ? widget.priorDrawingData?.strokes : null,
                ghostOpacity: _ghostOpacity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnatomicalEyePainter extends CustomPainter {
  final EyeType eye;
  final String diagramType;
  final double cdRatio;
  final List<VectorStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentBrushSize;
  final DrawingTool currentTool;
  final List<VectorStroke>? priorStrokes;
  final double ghostOpacity;

  AnatomicalEyePainter({
    required this.eye,
    required this.diagramType,
    required this.cdRatio,
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentBrushSize,
    required this.currentTool,
    this.priorStrokes,
    required this.ghostOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (diagramType == 'fundus') {
      _drawFundusBase(canvas, size, center, radius);
    } else if (diagramType == 'anterior') {
      _drawAnteriorBase(canvas, size, center, radius);
    } else {
      _drawPlainBase(canvas, size);
    }

    // Render Ghost Overlay (Prior Visit Strokes)
    if (priorStrokes != null && priorStrokes!.isNotEmpty) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: ghostOpacity));
      for (final s in priorStrokes!) {
        _renderSingleStroke(canvas, s);
      }
      canvas.restore();
    }

    // Render Saved Strokes
    for (final s in strokes) {
      _renderSingleStroke(canvas, s);
    }

    // Render Active In-Progress Drag Points
    if (currentPoints.length > 1) {
      final paint = Paint()
        ..color = currentTool == DrawingTool.eraser
            ? (diagramType == 'plain' ? Colors.white : const Color(0xFF451A03))
            : currentColor
        ..strokeWidth = currentBrushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawPlainBase(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  void _drawFundusBase(Canvas canvas, Size size, Offset center, double radius) {
    // Retinal Orange Radial Gradient
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF7C2D12), Color(0xFF451A03), Color(0xFF1E1B4B)],
        stops: const [0.1, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, bgPaint);

    // Optic Disc (Nasal side: OD right disc, OS left disc)
    final discX = eye == EyeType.OS ? size.width * 0.35 : size.width * 0.65;
    final discY = size.height * 0.48;
    final discCenter = Offset(discX, discY);
    const double discRadius = 32.0;

    final discPaint = Paint()..color = const Color(0xFFFEF3C7).withValues(alpha: 0.6);
    canvas.drawCircle(discCenter, discRadius, discPaint);
    final discBorder = Paint()
      ..color = const Color(0xFFFBBF24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(discCenter, discRadius, discBorder);

    // Optic Cup based on cdRatio
    final cupRadius = discRadius * cdRatio;
    final cupPaint = Paint()..color = const Color(0xFFFEF3C7).withValues(alpha: 0.9);
    canvas.drawCircle(discCenter, cupRadius, cupPaint);

    // Macula & Fovea
    final maculaX = eye == EyeType.OS ? size.width * 0.65 : size.width * 0.35;
    final maculaCenter = Offset(maculaX, discY);
    final maculaPaint = Paint()..color = const Color(0xFF991B1B).withValues(alpha: 0.7);
    canvas.drawCircle(maculaCenter, 20.0, maculaPaint);

    final foveaPaint = Paint()..color = const Color(0xFFFEE2E2);
    canvas.drawCircle(maculaCenter, 3.0, foveaPaint);

    // Major Retinal Vessels Arches
    final vesselPaint = Paint()
      ..color = const Color(0xFFDC2626).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final topVessel = Path();
    topVessel.addArc(Rect.fromCircle(center: Offset(discX, discY - 12), radius: 60), math.pi * 0.8, math.pi * 1.0);
    canvas.drawPath(topVessel, vesselPaint);

    final bottomVessel = Path();
    bottomVessel.addArc(Rect.fromCircle(center: Offset(discX, discY + 12), radius: 60), math.pi * 0.2, math.pi * 1.0);
    canvas.drawPath(bottomVessel, vesselPaint);
  }

  void _drawAnteriorBase(Canvas canvas, Size size, Offset center, double radius) {
    // Sclera/Background
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(center, radius, bgPaint);

    // Cornea Rim
    final corneaPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 20, corneaPaint);

    // Iris Ring
    final irisPaint = Paint()..color = const Color(0xFF1E3A8A).withValues(alpha: 0.7);
    canvas.drawCircle(center, radius - 45, irisPaint);

    // Pupil
    final pupilPaint = Paint()..color = const Color(0xFF020617);
    canvas.drawCircle(center, 45, pupilPaint);
  }

  void _renderSingleStroke(Canvas canvas, VectorStroke stroke) {
    final bgEraserColor = diagramType == 'plain' ? Colors.white : const Color(0xFF451A03);
    final paint = Paint()
      ..color = stroke.tool == DrawingTool.eraser ? bgEraserColor : stroke.color
      ..strokeWidth = stroke.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = stroke.tool == DrawingTool.symbol ? PaintingStyle.fill : PaintingStyle.stroke;

    if (stroke.tool == DrawingTool.symbol && stroke.points.isNotEmpty) {
      final pt = stroke.points.first;
      if (stroke.symbolType == 'cataract') {
        canvas.drawCircle(pt, 18.0, paint);
      } else if (stroke.symbolType == 'retinal_tear') {
        final path = Path();
        path.moveTo(pt.dx - 12, pt.dy + 10);
        path.lineTo(pt.dx, pt.dy - 12);
        path.lineTo(pt.dx + 12, pt.dy + 10);
        path.close();
        canvas.drawPath(path, paint);
      } else if (stroke.symbolType == 'drusen') {
        canvas.drawCircle(pt, 6.0, paint);
      } else {
        canvas.drawCircle(pt, stroke.size * 2, paint);
      }
      return;
    }

    if (stroke.points.length > 1) {
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnatomicalEyePainter oldDelegate) => true;
}
