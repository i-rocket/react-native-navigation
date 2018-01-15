package com.reactnativenavigation.viewcontrollers;

import android.app.Activity;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.view.ViewGroup;

import com.reactnativenavigation.parse.Options;
import com.reactnativenavigation.views.ReactComponent;

import java.util.Collection;

public abstract class ParentController<T extends ViewGroup> extends ViewController {

	public ParentController(final Activity activity, final String id) {
		super(activity, id);
	}

	@NonNull
	@Override
	public T getView() {
		return (T) super.getView();
	}

	@NonNull
	@Override
	protected abstract T createView();

    @NonNull
	public abstract Collection<? extends ViewController> getChildControllers();

	@Nullable
	@Override
	public ViewController findControllerById(final String id) {
		ViewController fromSuper = super.findControllerById(id);
		if (fromSuper != null) return fromSuper;

		for (ViewController child : getChildControllers()) {
			ViewController fromChild = child.findControllerById(id);
			if (fromChild != null) return fromChild;
		}

		return null;
	}

    public void applyOptions(Options options, ReactComponent childComponent) {

    }

	@Override
	public void destroy() {
		super.destroy();
		for (ViewController child : getChildControllers()) {
			child.destroy();
		}
	}

    void clearOptions() {

    }
}