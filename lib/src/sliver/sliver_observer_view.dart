/*
 * @Author: LinXunFeng linxunfeng@yeah.net
 * @Repo: https://github.com/LinXunFeng/flutter_scrollview_observer
 * @Date: 2022-08-08 00:20:03
 */
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:scrollview_observer/src/common/observer_typedef.dart';
import 'package:scrollview_observer/src/common/models/observe_model.dart';
import 'package:scrollview_observer/src/common/observer_widget.dart';
import 'package:scrollview_observer/src/gridview/grid_observer_mix.dart';
import 'package:scrollview_observer/src/listview/list_observer_mix.dart';
import 'package:scrollview_observer/src/notification.dart';
import 'package:scrollview_observer/src/sliver/models/sliver_viewport_observe_displaying_child_model.dart';
import 'package:scrollview_observer/src/utils/observer_utils.dart';

import 'models/sliver_viewport_observe_model.dart';
import 'sliver_observer_controller.dart';

class SliverViewObserver extends ObserverWidget<SliverObserverController,
    ObserveModel, ScrollViewOnceObserveNotification, RenderSliverList> {
  /// The callback of getting all slivers those are displayed in viewport.
  final Function(SliverViewportObserveModel)? onObserveViewport;

  final SliverObserverController? controller;

  const SliverViewObserver({
    Key? key,
    required Widget child,
    this.controller,
    @Deprecated('It will be removed in version 2, please use [sliverContexts] instead')
        List<BuildContext> Function()? sliverListContexts,
    List<BuildContext> Function()? sliverContexts,
    Function(Map<BuildContext, ObserveModel>)? onObserveAll,
    Function(ObserveModel)? onObserve,
    this.onObserveViewport,
    double leadingOffset = 0,
    double Function()? dynamicLeadingOffset,
    double toNextOverPercent = 1,
    List<ObserverAutoTriggerObserveType>? autoTriggerObserveTypes,
    ObserverTriggerOnObserveType triggerOnObserveType =
        ObserverTriggerOnObserveType.displayingItemsChange,
  }) : super(
          key: key,
          child: child,
          sliverController: controller,
          sliverContexts: sliverContexts ?? sliverListContexts,
          onObserveAll: onObserveAll,
          onObserve: onObserve,
          leadingOffset: leadingOffset,
          dynamicLeadingOffset: dynamicLeadingOffset,
          toNextOverPercent: toNextOverPercent,
          autoTriggerObserveTypes: autoTriggerObserveTypes,
          triggerOnObserveType: triggerOnObserveType,
        );

  @override
  State<SliverViewObserver> createState() => MixViewObserverState();
}

class MixViewObserverState extends ObserverWidgetState<
    SliverObserverController,
    ObserveModel,
    ScrollViewOnceObserveNotification,
    RenderSliverList,
    SliverViewObserver> with ListObserverMix, GridObserverMix {
  /// The last viewport observation result.
  SliverViewportObserveModel? lastViewportObserveResultModel;

  @override
  handleContexts({
    bool isForceObserve = false,
  }) {
    // Viewport
    handleObserveViewport(isForceObserve: isForceObserve);

    // Slivers（SliverList, GridView etc.）
    super.handleContexts(isForceObserve: isForceObserve);
  }

  @override
  ObserveModel? handleObserve(BuildContext ctx) {
    final _obj = ctx.findRenderObject();
    if (_obj is RenderSliverList) {
      return handleListObserve(ctx);
    } else if (_obj is RenderSliverGrid) {
      return handleGridObserve(ctx);
    }
    return null;
  }

  /// To observe the viewport.
  handleObserveViewport({
    bool isForceObserve = false,
  }) {
    final onObserveViewport = widget.onObserveViewport;
    if (onObserveViewport == null) return;

    final ctxs = fetchTargetSliverContexts();
    final objList = ctxs.map((e) => e.findRenderObject()).toList();
    if (objList.isEmpty) return;
    final firstObj = objList.first;
    if (firstObj == null) return;
    final viewport = ObserverUtils.findViewport(firstObj);
    if (viewport == null) return;

    var targetChild = viewport.firstChild;
    if (targetChild == null) return;
    var offset = widget.leadingOffset;
    if (widget.dynamicLeadingOffset != null) {
      offset = widget.dynamicLeadingOffset!();
    }
    final pixels = viewport.offset.pixels;
    final startCalcPixels = pixels + offset;

    int indexOfTargetChild = objList.indexOf(targetChild);

    // Find out the first sliver in viewport.
    while (!ObserverUtils.isValidListIndex(indexOfTargetChild) ||
        !ObserverUtils.isBelowOffsetSliverInViewport(
          viewportPixels: startCalcPixels,
          sliver: targetChild,
        )) {
      if (targetChild == null) break;
      final nextChild = viewport.childAfter(targetChild);
      if (nextChild == null) break;
      targetChild = nextChild;
      indexOfTargetChild = objList.indexOf(targetChild);
    }

    if (targetChild == null ||
        !ObserverUtils.isValidListIndex(indexOfTargetChild)) return;
    final targetCtx = ctxs[indexOfTargetChild];
    final firstChild = SliverViewportObserveDisplayingChildModel(
      sliverContext: targetCtx,
      sliver: targetChild,
    );

    List<SliverViewportObserveDisplayingChildModel> displayingChildModelList = [
      firstChild
    ];

    // Find the remaining children that are being displayed.
    final dimension =
        (viewport.offset as ScrollPositionWithSingleContext).viewportDimension;
    final viewportBottomOffset = pixels + dimension;
    targetChild = viewport.childAfter(targetChild);
    while (targetChild != null) {
      // The current targetChild is not displayed, so the later children don't
      // need to be check
      if (!ObserverUtils.isDisplayingSliverInViewport(
        sliver: targetChild,
        viewportPixels: startCalcPixels,
        viewportBottomOffset: viewportBottomOffset,
      )) break;

      indexOfTargetChild = objList.indexOf(targetChild);
      if (ObserverUtils.isValidListIndex(indexOfTargetChild)) {
        // The current targetChild is target.
        final context = ctxs[indexOfTargetChild];
        displayingChildModelList.add(SliverViewportObserveDisplayingChildModel(
          sliverContext: context,
          sliver: targetChild,
        ));
      }
      // continue to check next child.
      targetChild = viewport.childAfter(targetChild);
    }
    var model = SliverViewportObserveModel(
      viewport: viewport,
      firstChild: firstChild,
      displayingChildModelList: displayingChildModelList,
    );
    if (isForceObserve ||
        widget.triggerOnObserveType == ObserverTriggerOnObserveType.directly) {
      onObserveViewport(model);
    } else if (model != lastViewportObserveResultModel) {
      onObserveViewport(model);
    }
    lastViewportObserveResultModel = model;
  }
}
