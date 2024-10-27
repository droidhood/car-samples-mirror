/*
 * Copyright 2023 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package androidx.car.app.sample.showcase.common.screens.navigationdemos;

<<<<<<< HEAD
<<<<<<< HEAD
=======
import androidx.annotation.NonNull;
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
>>>>>>> ff0f88fd ([create-pull-request] automated change)
import androidx.car.app.CarContext;
import androidx.car.app.Screen;
import androidx.car.app.model.CarColor;
import androidx.car.app.model.Template;
import androidx.car.app.navigation.model.NavigationTemplate;
import androidx.car.app.navigation.model.RoutingInfo;
import androidx.lifecycle.DefaultLifecycleObserver;

<<<<<<< HEAD
<<<<<<< HEAD
import org.jspecify.annotations.NonNull;

=======
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
import org.jspecify.annotations.NonNull;

>>>>>>> ff0f88fd ([create-pull-request] automated change)
/** A screen that shows the navigation template in loading state. */
public final class LoadingDemoScreen extends Screen implements DefaultLifecycleObserver {
    private final RoutingDemoModelFactory mRoutingDemoModelFactory;
    public LoadingDemoScreen(@NonNull CarContext carContext) {
        super(carContext);
        mRoutingDemoModelFactory = new RoutingDemoModelFactory(carContext);
    }

<<<<<<< HEAD
<<<<<<< HEAD
    @Override
    public @NonNull Template onGetTemplate() {
=======
    @NonNull
    @Override
    public Template onGetTemplate() {
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
    @Override
    public @NonNull Template onGetTemplate() {
>>>>>>> ff0f88fd ([create-pull-request] automated change)
        return new NavigationTemplate.Builder()
                .setNavigationInfo(new RoutingInfo.Builder().setLoading(true).build())
                .setActionStrip(mRoutingDemoModelFactory.getActionStrip(this::finish))
                .setBackgroundColor(CarColor.SECONDARY)
                .build();
    }
}
