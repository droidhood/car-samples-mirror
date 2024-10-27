/*
 * Copyright (C) 2021 The Android Open Source Project
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

package androidx.car.app.sample.showcase.common.common;

import static androidx.car.app.CarToast.LENGTH_LONG;

import android.content.Intent;
import android.net.Uri;

<<<<<<< HEAD
<<<<<<< HEAD
=======
import androidx.annotation.NonNull;
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
>>>>>>> ff0f88fd ([create-pull-request] automated change)
import androidx.car.app.CarContext;
import androidx.car.app.CarToast;
import androidx.car.app.HostException;
import androidx.car.app.Screen;
import androidx.car.app.model.Action;
import androidx.car.app.model.CarColor;
import androidx.car.app.model.Header;
import androidx.car.app.model.Pane;
import androidx.car.app.model.PaneTemplate;
import androidx.car.app.model.Row;
import androidx.car.app.model.Template;
import androidx.car.app.sample.showcase.common.R;

<<<<<<< HEAD
<<<<<<< HEAD
import org.jspecify.annotations.NonNull;

=======
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
import org.jspecify.annotations.NonNull;

>>>>>>> ff0f88fd ([create-pull-request] automated change)
/** A screen that displays the details of a place. */
public class PlaceDetailsScreen extends Screen {
    private final PlaceInfo mPlace;

    private PlaceDetailsScreen(@NonNull CarContext carContext, @NonNull PlaceInfo place) {
        super(carContext);
        mPlace = place;
    }

    /** Creates an instance of {@link PlaceDetailsScreen}. */
<<<<<<< HEAD
<<<<<<< HEAD
    public static @NonNull PlaceDetailsScreen create(
=======
    @NonNull
    public static PlaceDetailsScreen create(
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
    public static @NonNull PlaceDetailsScreen create(
>>>>>>> ff0f88fd ([create-pull-request] automated change)
            @NonNull CarContext carContext, @NonNull PlaceInfo place) {
        return new PlaceDetailsScreen(carContext, place);
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
        Pane.Builder paneBuilder =
                new Pane.Builder()
                        .addAction(
                                new Action.Builder()
                                        .setTitle(getCarContext().getString(R.string.navigate))
                                        .setBackgroundColor(CarColor.BLUE)
                                        .setOnClickListener(this::onClickNavigate)
                                        .build())
                        .addAction(
                                new Action.Builder()
                                        .setTitle(getCarContext().getString(R.string.dial))
                                        .setOnClickListener(this::onClickDial)
                                        .build())
                        .addRow(
                                new Row.Builder()
                                        .setTitle(getCarContext().getString(R.string.address))
                                        .addText(mPlace.address)
                                        .build())
                        .addRow(
                                new Row.Builder()
                                        .setTitle(getCarContext().getString(R.string.phone))
                                        .addText(mPlace.phoneNumber)
                                        .build());

        return new PaneTemplate.Builder(paneBuilder.build())
                .setHeader(new Header.Builder()
<<<<<<< HEAD
                        .setTitle(mPlace.title.toString())
=======
                        .setTitle(mPlace.title)
>>>>>>> 7365d9da ([create-pull-request] automated change)
                        .setStartHeaderAction(Action.BACK)
                        .build())
                .build();
    }

    private void onClickNavigate() {
        Uri uri = Uri.parse("geo:0,0?q=" + mPlace.address);
        Intent intent = new Intent(CarContext.ACTION_NAVIGATE, uri);

        try {
            getCarContext().startCarApp(intent);
        } catch (HostException e) {
            CarToast.makeText(
                            getCarContext(),
                            getCarContext().getString(R.string.fail_start_nav),
                            LENGTH_LONG)
                    .show();
        }
    }

    private void onClickDial() {
        Uri uri = Uri.parse("tel:" + mPlace.phoneNumber);
        Intent intent = new Intent(Intent.ACTION_DIAL, uri);

        try {
            getCarContext().startCarApp(intent);
        } catch (HostException e) {
            CarToast.makeText(
                            getCarContext(),
                            getCarContext().getString(R.string.fail_start_dialer),
                            LENGTH_LONG)
                    .show();
        }
    }
}
